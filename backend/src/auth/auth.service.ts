import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import * as argon2 from 'argon2';
import { DataSource } from 'typeorm';
import { IsNull, MoreThan } from 'typeorm';
import type { RoleCode } from '../common/authorization/permission-policies';
import { AccountStatus } from '../users/account-status';
import { CredentialEntity } from '../users/credential.entity';
import { IdentityEntity } from '../users/identity.entity';
import { UserRoleEntity } from '../users/user-role.entity';
import { UserEntity } from '../users/user.entity';
import { ProviderApplicationEntity } from '../providers/provider-application.entity';
import { ProviderOnboardingStatus } from '../providers/provider-onboarding-status';
import {
  CUSTOMER_ROLE_ID,
  LOCAL_EMAIL_PROVIDER,
  PROVIDER_APPLICANT_ROLE_ID,
} from './auth.constants';
import { AuthenticationResponse, EmailPasswordDto } from './auth.dto';
import { TokenLifecycleService } from './token-lifecycle.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly tokenLifecycle: TokenLifecycleService,
  ) {}

  registerCustomer(input: EmailPasswordDto): Promise<AuthenticationResponse> {
    return this.register(input, {
      role: 'customer',
      roleId: CUSTOMER_ROLE_ID,
      reason: 'Customer self-registration',
      providerApplicant: false,
    });
  }

  registerProvider(input: EmailPasswordDto): Promise<AuthenticationResponse> {
    return this.register(input, {
      role: 'provider_applicant',
      roleId: PROVIDER_APPLICANT_ROLE_ID,
      reason: 'Provider self-registration',
      providerApplicant: true,
    });
  }

  private async register(
    input: EmailPasswordDto,
    persona: {
      role: 'customer' | 'provider_applicant';
      roleId: string;
      reason: string;
      providerApplicant: boolean;
    },
  ): Promise<AuthenticationResponse> {
    const passwordHash = await argon2.hash(input.password, {
      type: argon2.argon2id,
    });

    let user: UserEntity;
    try {
      user = await this.dataSource.transaction(async (manager) => {
        const existing = await manager.findOneBy(IdentityEntity, {
          provider: LOCAL_EMAIL_PROVIDER,
          subject: input.email,
        });
        if (existing) throw new ConflictException('Unable to create account');

        const createdUser = await manager.save(
          manager.create(UserEntity, {
            status: AccountStatus.PendingVerification,
          }),
        );
        const identity = await manager.save(
          manager.create(IdentityEntity, {
            userId: createdUser.id,
            provider: LOCAL_EMAIL_PROVIDER,
            subject: input.email,
            verifiedAt: null,
          }),
        );
        await manager.save(
          manager.create(CredentialEntity, {
            identityId: identity.id,
            passwordHash,
          }),
        );
        await manager.save(
          manager.create(UserRoleEntity, {
            userId: createdUser.id,
            roleId: persona.roleId,
            assignedByUserId: null,
            reason: persona.reason,
            expiresAt: null,
          }),
        );
        if (persona.providerApplicant) {
          await manager.save(
            manager.create(ProviderApplicationEntity, {
              userId: createdUser.id,
              status: ProviderOnboardingStatus.Unverified,
            }),
          );
        }
        return createdUser;
      });
    } catch (error: unknown) {
      if (
        error instanceof ConflictException ||
        (typeof error === 'object' &&
          error !== null &&
          'code' in error &&
          error.code === '23505')
      ) {
        throw new ConflictException('Unable to create account');
      }
      throw error;
    }

    return this.tokenLifecycle.issueSession(user, persona.role);
  }

  async login(input: EmailPasswordDto): Promise<AuthenticationResponse> {
    const { identity } = await this.validateCredentials(input);
    const providerRoles = await this.activeRoles(identity.userId);
    const resolvedRole = providerRoles.includes('verified_provider')
      ? 'verified_provider'
      : providerRoles.includes('provider_applicant')
        ? 'provider_applicant'
        : 'customer';
    return this.tokenLifecycle.issueSession(identity.user, resolvedRole);
  }

  async loginAdmin(input: EmailPasswordDto): Promise<AuthenticationResponse> {
    const { identity } = await this.validateCredentials(input, true);
    const staffRoles = (await this.activeRoles(identity.userId)).filter(
      (role) => AuthService.staffRoles.has(role),
    );
    if (staffRoles.length !== 1) {
      throw new UnauthorizedException('Invalid email or password');
    }
    return this.tokenLifecycle.issueSession(identity.user, staffRoles[0]);
  }

  private static readonly staffRoles = new Set<RoleCode>([
    'provider_reviewer',
    'support_agent',
    'trust_safety_reviewer',
    'finance_operator',
    'service_catalog_manager',
    'operations_administrator',
    'security_administrator',
    'auditor',
  ]);

  private async validateCredentials(
    input: EmailPasswordDto,
    staffOnly = false,
  ) {
    const identity = await this.dataSource
      .getRepository(IdentityEntity)
      .findOne({
        where: { provider: LOCAL_EMAIL_PROVIDER, subject: input.email },
        relations: { user: true },
      });
    const credential = identity
      ? await this.dataSource.getRepository(CredentialEntity).findOneBy({
          identityId: identity.id,
        })
      : null;

    const valid = credential
      ? await argon2.verify(credential.passwordHash, input.password)
      : false;
    if (!identity || !credential || !valid) {
      throw new UnauthorizedException('Invalid email or password');
    }
    if (
      identity.user.status !== AccountStatus.Active &&
      (staffOnly || identity.user.status !== AccountStatus.PendingVerification)
    ) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return { identity, credential };
  }

  private async activeRoles(userId: string): Promise<RoleCode[]> {
    const assignments = await this.dataSource
      .getRepository(UserRoleEntity)
      .find({
        where: [
          { userId, expiresAt: IsNull() },
          { userId, expiresAt: MoreThan(new Date()) },
        ],
        relations: { role: true },
      });
    return assignments.map((assignment) => assignment.role.code as RoleCode);
  }
}
