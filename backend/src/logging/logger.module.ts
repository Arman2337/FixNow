import { Module } from '@nestjs/common';
import { LoggerModule as PinoLoggerModule } from 'nestjs-pino';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { EnvironmentVariables } from '../config/env.validation';
import { resolveRequestId } from './request-correlation';

@Module({
  imports: [
    PinoLoggerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService<EnvironmentVariables>) => {
        const isProduction = configService.get('NODE_ENV') === 'production';
        return {
          pinoHttp: {
            level: configService.get('LOG_LEVEL'),
            // A09. One id per request, continued from an upstream proxy when
            // the value is safe to put in a log line, and visible to the client
            // via RequestCorrelationMiddleware.
            genReqId: (req: { headers: Record<string, unknown> }) =>
              resolveRequestId(req.headers['x-request-id']),
            redact: {
              paths: ['req.headers.authorization', 'req.headers.cookie'],
              censor: '[REDACTED]',
            },
            transport: isProduction
              ? undefined
              : {
                  target: 'pino-pretty',
                  options: {
                    singleLine: true,
                  },
                },
          },
        };
      },
    }),
  ],
})
export class AppLoggerModule {}
