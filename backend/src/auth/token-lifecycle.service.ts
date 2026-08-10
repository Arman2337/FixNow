import {
  Inject,
  Injectable,
  HttpException,
  HttpStatus,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  randomUUID,
  timingSafeEqual,
} from 'crypto';
import { ConfigService } from '@nestjs/config';
import { DataSource, IsNull } from 'typeorm';
import { OTP_DELIVERY } from '../notifications/otp-delivery';
import type { OtpDelivery } from '../notifications/otp-delivery';
import { AccountStatus } from '../users/account-status';
import { IdentityEntity } from '../users/identity.entity';
import { UserEntity } from '../users/user.entity';
import {
  ACCESS_TOKEN_AUDIENCE,
  ACCESS_TOKEN_ISSUER,
  ACCESS_TOKEN_TTL_SECONDS,
  LOCAL_EMAIL_PROVIDER,
} from './auth.constants';
import { AuthAuditEventEntity } from './auth-audit-event.entity';
import { AuthSessionEntity } from './auth-session.entity';
import { AuthenticationResponse } from './auth.dto';
import { OtpChallengeEntity } from './otp-challenge.entity';

const OTP_TTL_MS = 10 * 60_000;
const OTP_RESEND_MS = 60_000;
const REFRESH_TTL_MS = 30 * 24 * 60 * 60_000;

@Injectable()
export class TokenLifecycleService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    @Inject(OTP_DELIVERY) private readonly delivery: OtpDelivery,
  ) {}

  async issueSession(
    user: UserEntity,
    role: 'customer' | 'provider_applicant',
  ): Promise<AuthenticationResponse> {
    const refreshToken = randomBytes(32).toString('base64url');
    const session = await this.dataSource
      .getRepository(AuthSessionEntity)
      .save({
        userId: user.id,
        tokenFamilyId: randomUUID(),
        refreshTokenHash: this.hashToken(refreshToken),
        role,
        expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
        revokedAt: null,
        revokeReason: null,
        replacedBySessionId: null,
      });
    await this.audit(user.id, 'session.issued', 'success');
    return this.response(user, role, refreshToken, session.id);
  }

  async refresh(refreshToken: string): Promise<AuthenticationResponse> {
    const hash = this.hashToken(refreshToken);
    const result = await this.dataSource.transaction(async (manager) => {
      const session = await manager.findOne(AuthSessionEntity, {
        where: { refreshTokenHash: hash },
        lock: { mode: 'pessimistic_write' },
      });
      if (!session) throw new UnauthorizedException('Invalid refresh token');
      if (session.revokedAt) {
        await manager.update(
          AuthSessionEntity,
          { tokenFamilyId: session.tokenFamilyId, revokedAt: IsNull() },
          { revokedAt: new Date(), revokeReason: 'replay_detected' },
        );
        await manager.save(
          manager.create(AuthAuditEventEntity, {
            userId: session.userId,
            eventType: 'session.replay_detected',
            outcome: 'denied',
          }),
        );
        return null;
      }
      if (session.expiresAt.getTime() <= Date.now()) {
        session.revokedAt = new Date();
        session.revokeReason = 'expired';
        await manager.save(session);
        return null;
      }
      const user = await manager.findOneByOrFail(UserEntity, {
        id: session.userId,
      });
      if (
        user.status !== AccountStatus.Active &&
        user.status !== AccountStatus.PendingVerification
      ) {
        throw new UnauthorizedException('Invalid refresh token');
      }
      const nextToken = randomBytes(32).toString('base64url');
      const next = await manager.save(
        manager.create(AuthSessionEntity, {
          userId: session.userId,
          tokenFamilyId: session.tokenFamilyId,
          refreshTokenHash: this.hashToken(nextToken),
          role: session.role,
          expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
          revokedAt: null,
          revokeReason: null,
          replacedBySessionId: null,
        }),
      );
      session.revokedAt = new Date();
      session.revokeReason = 'rotated';
      session.replacedBySessionId = next.id;
      await manager.save(session);
      await manager.save(
        manager.create(AuthAuditEventEntity, {
          userId: session.userId,
          eventType: 'session.rotated',
          outcome: 'success',
        }),
      );
      return this.response(
        user,
        session.role as 'customer' | 'provider_applicant',
        nextToken,
        next.id,
      );
    });
    if (!result) throw new UnauthorizedException('Invalid refresh token');
    return result;
  }

  async logout(refreshToken: string, all: boolean): Promise<void> {
    const repository = this.dataSource.getRepository(AuthSessionEntity);
    const session = await repository.findOneBy({
      refreshTokenHash: this.hashToken(refreshToken),
    });
    if (!session) return;
    const criteria = all
      ? { userId: session.userId, revokedAt: IsNull() }
      : { id: session.id, revokedAt: IsNull() };
    await repository.update(criteria, {
      revokedAt: new Date(),
      revokeReason: all ? 'logout_all' : 'logout',
    });
    await this.audit(
      session.userId,
      all ? 'session.logout_all' : 'session.logout',
      'success',
    );
  }

  async requestOtp(email: string): Promise<void> {
    const identity = await this.dataSource
      .getRepository(IdentityEntity)
      .findOne({
        where: { provider: LOCAL_EMAIL_PROVIDER, subject: email },
        relations: { user: true },
      });
    if (!identity || identity.verifiedAt) return;
    const challenges = this.dataSource.getRepository(OtpChallengeEntity);
    const latest = await challenges.findOne({
      where: { identityId: identity.id },
      order: { createdAt: 'DESC' },
    });
    if (latest && latest.resendAfter.getTime() > Date.now()) {
      throw new HttpException('Try again later', HttpStatus.TOO_MANY_REQUESTS);
    }
    const code = randomInt(100_000, 1_000_000).toString();
    await this.delivery.sendVerificationCode(email, code);
    await challenges.save({
      identityId: identity.id,
      codeHash: this.hashOtp(identity.id, code),
      expiresAt: new Date(Date.now() + OTP_TTL_MS),
      resendAfter: new Date(Date.now() + OTP_RESEND_MS),
      attemptsRemaining: 5,
      consumedAt: null,
    });
    await this.audit(identity.userId, 'otp.sent', 'success');
  }

  async verifyOtp(email: string, code: string): Promise<void> {
    const identity = await this.dataSource
      .getRepository(IdentityEntity)
      .findOne({
        where: { provider: LOCAL_EMAIL_PROVIDER, subject: email },
        relations: { user: true },
      });
    if (!identity) throw new UnauthorizedException('Invalid verification code');
    const challenges = this.dataSource.getRepository(OtpChallengeEntity);
    const challenge = await challenges.findOne({
      where: { identityId: identity.id, consumedAt: IsNull() },
      order: { createdAt: 'DESC' },
    });
    if (
      !challenge ||
      challenge.expiresAt.getTime() <= Date.now() ||
      challenge.attemptsRemaining <= 0
    ) {
      throw new UnauthorizedException('Invalid verification code');
    }
    const actual = Buffer.from(this.hashOtp(identity.id, code));
    const expected = Buffer.from(challenge.codeHash);
    if (!timingSafeEqual(actual, expected)) {
      challenge.attemptsRemaining -= 1;
      await challenges.save(challenge);
      await this.audit(identity.userId, 'otp.verify', 'denied');
      throw new UnauthorizedException('Invalid verification code');
    }
    challenge.consumedAt = new Date();
    await challenges.save(challenge);
    await this.dataSource.getRepository(IdentityEntity).update(identity.id, {
      verifiedAt: new Date(),
    });
    await this.dataSource.getRepository(UserEntity).update(identity.userId, {
      status: AccountStatus.Active,
      statusReason: 'Email verified',
      statusChangedAt: new Date(),
    });
    await this.audit(identity.userId, 'otp.verify', 'success');
  }

  private response(
    user: UserEntity,
    role: 'customer' | 'provider_applicant',
    refreshToken: string,
    sessionId: string,
  ): AuthenticationResponse {
    const accessToken = this.jwtService.sign(
      { accountStatus: user.status, role, sessionId },
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
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: ACCESS_TOKEN_TTL_SECONDS,
    };
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private hashOtp(identityId: string, code: string): string {
    return createHmac('sha256', this.config.getOrThrow<string>('OTP_SECRET'))
      .update(`${identityId}:${code}`)
      .digest('hex');
  }

  private async audit(
    userId: string | null,
    eventType: string,
    outcome: string,
  ): Promise<void> {
    await this.dataSource.getRepository(AuthAuditEventEntity).save({
      userId,
      eventType,
      outcome,
    });
  }
}
