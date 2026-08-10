import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationsModule } from '../notifications/notifications.module';
import { AuthSessionEntity } from './auth-session.entity';
import { OtpChallengeEntity } from './otp-challenge.entity';
import { AuthAuditEventEntity } from './auth-audit-event.entity';
import { TokenLifecycleController } from './token-lifecycle.controller';
import { TokenLifecycleService } from './token-lifecycle.service';
import { AuthorizationGuard } from '../common/authorization/authorization.guard';
import { AuthorizationPolicyService } from '../common/authorization/authorization-policy.service';
import { AuthorizationService } from '../common/authorization/authorization.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      AuthSessionEntity,
      OtpChallengeEntity,
      AuthAuditEventEntity,
    ]),
    NotificationsModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [AuthController, TokenLifecycleController],
  providers: [
    AuthService,
    TokenLifecycleService,
    AuthorizationPolicyService,
    AuthorizationService,
    AuthorizationGuard,
    { provide: APP_GUARD, useExisting: AuthorizationGuard },
  ],
  exports: [AuthService, AuthorizationService],
})
export class AuthModule {}
