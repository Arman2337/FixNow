import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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
  providers: [AuthService, TokenLifecycleService],
  exports: [AuthService],
})
export class AuthModule {}
