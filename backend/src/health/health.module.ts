import { Global, Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { ObservabilityModule } from '../observability/observability.module';
import { HealthController } from './health.controller';
import { ReadinessState } from './readiness-state.service';
import { SystemHealthService } from './system-health.service';

/**
 * Global, because the drain signal and dependency degradation are not the
 * health module's business alone. The cache module reports a Redis outage
 * (BUG-012) and `main.ts` starts the drain (OPS-002), and both of those need the
 * same answer - "should this instance still be sent work" - without either of
 * them importing a health controller.
 *
 * `ObservabilityModule` is imported here for `SystemHealthService`, which reads
 * the metric registry for the dashboard's "recent metrics" panel. It was
 * previously not imported, on the grounds recorded below; that reasoning was
 * about the metrics *controller* and does not extend to the metrics *service*.
 *
 * The original note, kept because the failure it describes is still live:
 * `ObservabilityModule` used to be imported here purely so `/health/metrics`
 * could sit next to the other probes, and that made it reachable only through
 * another `@Global()` module, which Nest resolves by a different path than a
 * first-class import. The app hung inside `NestFactory.create` with no output at
 * all, and removing the import produced an immediate
 * `UnknownDependenciesException` proving the service had been resolving through
 * that path rather than by global registration. Two things changed that make the
 * import safe now, and both are load-bearing:
 *
 *  - `AppModule` still imports `ObservabilityModule` as a top-level module, so
 *    this is not the only resolution path. Nest resolves a first-class import
 *    before falling back to global registration.
 *  - `ObservabilityModule` provides only `ObservabilityService` and the error
 *    reporter. Importing it registers no controllers here, so
 *    `MetricsController` is still mounted once, by its own module.
 *
 * `cache.module.spec.ts` imports the real `HealthModule` without
 * `ObservabilityModule`, and fails to resolve without this — which is how the
 * dependency is discovered rather than assumed.
 */
@Global()
@Module({
  imports: [TerminusModule, ObservabilityModule],
  controllers: [HealthController],
  providers: [ReadinessState, SystemHealthService],
  exports: [ReadinessState],
})
export class HealthModule {}
