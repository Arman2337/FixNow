import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvironmentVariables } from '../config/env.validation';
import { ObservabilityService } from './observability.service';
import { MetricsController } from './metrics.controller';
import {
  HttpErrorReporter,
  NoopErrorReporter,
  type ErrorReporter,
} from './error-reporter';

/**
 * Global so instrumentation can be called from any module without threading the
 * service through constructors that have no other reason to know about metrics.
 * The registry itself is cheap — a few maps — so there is no cost concern that
 * would justify the ceremony.
 *
 * The scrape route is `/health/metrics`, declared by `MetricsController` rather
 * than by the health controller, so the observability concern owns its own
 * surface and `HealthModule` does not have to know about it.
 *
 * `ERROR_REPORTING_DSN` selects the error reporter: a DSN gives the HTTP
 * transport, and an absent one gives a no-op. Choosing by configuration rather
 * than by code means a deployment can turn reporting on without a rebuild, and a
 * missing DSN degrades to "the log is authoritative" rather than to an error.
 */
@Global()
@Module({
  controllers: [MetricsController],
  providers: [
    ObservabilityService,
    {
      provide: 'ERROR_REPORTER',
      useFactory: (
        config: ConfigService<EnvironmentVariables, true>,
      ): ErrorReporter => {
        const dsn = config.get('ERROR_REPORTING_DSN', { infer: true });
        if (!dsn) return new NoopErrorReporter();
        return new HttpErrorReporter(
          dsn,
          config.get('NODE_ENV', { infer: true }) ?? 'development',
          config.get('APP_RELEASE', { infer: true }),
        );
      },
      inject: [ConfigService],
    },
  ],
  exports: [ObservabilityService],
})
export class ObservabilityModule {}
