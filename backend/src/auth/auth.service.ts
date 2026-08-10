import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { DataSource } from 'typeorm';
import { AccountStatus } from '../users/account-status';
import { CredentialEntity } from '../users/credential.entity';
import { IdentityEntity } from '../users/identity.entity';
import { UserRoleEntity } from '../users/user-role.entity';
import { UserEntity } from '../users/user.entity';
import { ProviderApplicationEntity } from '../providers/provider-application.entity';
import { ProviderOnboardingStatus } from '../providers/provider-onboarding-status';
import {
  ACCESS_TOKEN_AUDIENCE,
  ACCESS_TOKEN_ISSUER,
  ACCESS_TOKEN_TTL_SECONDS,
  CUSTOMER_ROLE_ID,
  LOCAL_EMAIL_PROVIDER,
  PROVIDER_APPLICANT_ROLE_ID,
} from './auth.constants';
import { AuthenticationResponse, EmailPasswordDto } from './auth.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly jwtService: JwtService,
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

    return this.createAuthenticationResponse(user, persona.role);
  }

  async login(input: EmailPasswordDto): Promise<AuthenticationResponse> {
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
      identity.user.status !== AccountStatus.PendingVerification
    ) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.createAuthenticationResponse(identity.user, 'customer');
  }

  private async createAuthenticationResponse(
    user: UserEntity,
    role: 'customer' | 'provider_applicant',
  ): Promise<AuthenticationResponse> {
    const accessToken = await this.jwtService.signAsync(
      { accountStatus: user.status, role },
      {
        subject: user.id,
        issuer: ACCESS_TOKEN_ISSUER,
        audience: ACCESS_TOKEN_AUDIENCE,
        expiresIn: ACCESS_TOKEN_TTL_SECONDS,
      },
    );
    return {
      userId: user.id,
      accessToken,
      tokenType: 'Bearer',
      expiresIn: ACCESS_TOKEN_TTL_SECONDS,
    };
  }
}
