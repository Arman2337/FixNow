import {
  ConflictException,
  Injectable,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import * as argon2 from 'argon2';
import { createHash, randomBytes } from 'node:crypto';
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
import { CustomerProfileEntity } from '../users/customer-profile.entity';
import {
  CUSTOMER_ROLE_ID,
  LOCAL_EMAIL_PROVIDER,
  PROVIDER_APPLICANT_ROLE_ID,
} from './auth.constants';
import { AuthenticationResponse, EmailPasswordDto } from './auth.dto';
import { TokenLifecycleService } from './token-lifecycle.service';
import { PasswordResetTokenEntity } from '../users/password-reset-token.entity';

@Injectable()
export class AuthService {
  /**
   * Consecutive failures before an account is locked.
   *
   * Five is chosen against argon2's cost: at the configured parameters a single
   * verify is expensive enough that this threshold caps an attacker's CPU spend
   * as a side effect of capping their guesses.
   */
  static readonly MAX_FAILED_LOGINS = 5;

  /**
   * How long a lockout lasts.
   *
   * Deliberately time-boxed rather than requiring an administrator. A lockout
   * is a real availability cost, and a support-desk dependency as the only way
   * back into your own account is its own outage.
   */
  static readonly LOGIN_LOCKOUT_MS = 15 * 60_000;

  /** How long a reset link stays usable. */
  static readonly PASSWORD_RESET_TTL_MS = 30 * 60_000;

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
    if (!input.mobile?.trim()) {
      throw new BadRequestException(
        'Mobile number is required for registration.',
      );
    }

    const passwordHash = await this.hashPassword(input.password);

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
            phone: input.mobile?.trim() || null,
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
        if (input.fullName && input.fullName.trim().length > 0) {
          await manager.save(
            manager.create(CustomerProfileEntity, {
              userId: createdUser.id,
              displayName: input.fullName.trim(),
            }),
          );
        }
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

    // A07. Checked before the (deliberately slow) argon2 verify, so a locked
    // account cannot be used to burn CPU either. Every rejection below returns
    // the same message: distinguishing "locked" from "wrong password" would
    // tell an attacker which emails have accounts.
    if (credential?.lockedUntil && credential.lockedUntil > new Date()) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const valid = credential
      ? await argon2.verify(credential.passwordHash, input.password)
      : false;
    if (!identity || !credential || !valid) {
      if (credential) await this.recordFailedLogin(credential);
      throw new UnauthorizedException('Invalid email or password');
    }
    if (
      identity.user.status !== AccountStatus.Active &&
      (staffOnly || identity.user.status !== AccountStatus.PendingVerification)
    ) {
      throw new UnauthorizedException('Invalid email or password');
    }

    // Success clears the counter, so a user who mistypes twice and then
    // succeeds does not carry the failures toward a later lockout.
    if (credential.failedLoginCount !== 0 || credential.lockedUntil !== null) {
      await this.dataSource
        .getRepository(CredentialEntity)
        .update(
          { id: credential.id },
          { failedLoginCount: 0, lockedUntil: null },
        );
      credential.failedLoginCount = 0;
      credential.lockedUntil = null;
    }

    return { identity, credential };
  }

  /**
   * Counts a failed verification and locks the credential at the threshold.
   *
   * The counter lives on the credential row rather than in Redis or memory
   * because it must survive a restart and be shared across replicas, and
   * because a lockout that resets on deploy is not a lockout.
   *
   * The lock is applied with a conditional update so two concurrent failures
   * for the same account cannot both read the pre-increment value and leave
   * the counter one short of the threshold.
   */
  private async recordFailedLogin(credential: CredentialEntity): Promise<void> {
    const repository = this.dataSource.getRepository(CredentialEntity);
    const next = credential.failedLoginCount + 1;
    if (next < AuthService.MAX_FAILED_LOGINS) {
      await repository.update(
        { id: credential.id },
        { failedLoginCount: next },
      );
      credential.failedLoginCount = next;
      return;
    }
    const lockedUntil = new Date(Date.now() + AuthService.LOGIN_LOCKOUT_MS);
    await repository.update(
      { id: credential.id, failedLoginCount: credential.failedLoginCount },
      { failedLoginCount: next, lockedUntil },
    );
    credential.failedLoginCount = next;
    credential.lockedUntil = lockedUntil;
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

  /**
   * Issues a password-reset link for a local-email identity.
   *
   * Returns the plaintext token to the caller only when the address has an
   * account. That is unavoidable - the link has to be emailed - and the caller
   * sends an identical response either way, so the endpoint is not an account
   * oracle.
   *
   * The stored value is a SHA-256 hash, matching refresh-token handling: a
   * database disclosure must not yield usable reset links, which would hand an
   * attacker who can read the database every account.
   */
  async requestPasswordReset(email: string): Promise<string | null> {
    const identity = await this.dataSource
      .getRepository(IdentityEntity)
      .findOne({
        where: { provider: LOCAL_EMAIL_PROVIDER, subject: email },
      });
    if (!identity) return null;

    const token = randomBytes(32).toString('hex');
    const repository = this.dataSource.getRepository(PasswordResetTokenEntity);
    // Invalidate outstanding links so a second request supersedes the first,
    // rather than leaving two live credentials for one account.
    await repository.update(
      { identityId: identity.id, consumedAt: IsNull() },
      { consumedAt: new Date() },
    );
    await repository.insert(
      repository.create({
        identityId: identity.id,
        tokenHash: this.hashResetToken(token),
        expiresAt: new Date(Date.now() + AuthService.PASSWORD_RESET_TTL_MS),
        consumedAt: null,
      }),
    );
    return token;
  }

  /**
   * Consumes a reset token and sets a new password.
   *
   * Single-use, enforced by a conditional update on `consumed_at` rather than
   * by a read-then-write, so two concurrent redemptions of the same link cannot
   * both succeed.
   *
   * Clearing the lockout is deliberate: someone who has just proven control of
   * the mailbox should not be locked out by the failed attempts that led them
   * to reset in the first place.
   */
  async resetPassword(token: string, newPassword: string): Promise<void> {
    const repository = this.dataSource.getRepository(PasswordResetTokenEntity);
    const claim = await repository.findOne({
      where: { tokenHash: this.hashResetToken(token), consumedAt: IsNull() },
    });
    if (!claim || claim.expiresAt <= new Date()) {
      throw new BadRequestException(
        'This reset link is invalid or has expired',
      );
    }

    const { affected } = await repository.update(
      { id: claim.id, consumedAt: IsNull() },
      { consumedAt: new Date() },
    );
    if (affected !== 1) {
      throw new BadRequestException(
        'This reset link is invalid or has expired',
      );
    }

    const identity = await this.dataSource
      .getRepository(IdentityEntity)
      .findOneBy({ id: claim.identityId });
    if (!identity) {
      throw new BadRequestException(
        'This reset link is invalid or has expired',
      );
    }

    await this.dataSource.getRepository(CredentialEntity).update(
      { identityId: identity.id },
      {
        passwordHash: await this.hashPassword(newPassword),
        failedLoginCount: 0,
        lockedUntil: null,
      },
    );

    // Outstanding sessions were authenticated with the old password; a reset
    // is the standard signal that they should not survive it.
    await this.tokenLifecycle.revokeAllForUser(identity.userId);
  }

  private hashResetToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  /**
   * The one place a password hash is produced.
   *
   * Argon2id at default parameters, shared by registration and reset so a
   * reset cannot silently produce a weaker hash than a sign-up did.
   */
  private hashPassword(password: string): Promise<string> {
    return argon2.hash(password, { type: argon2.argon2id });
  }
}
