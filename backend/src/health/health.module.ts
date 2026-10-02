import { Global, Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health.controller';
import { ReadinessState } from './readiness-state.service';

/**
 * Global, because the drain signal and dependency degradation are not the
 * health module's business alone. The cache module reports a Redis outage
 * (BUG-012) and `main.ts` starts the drain (OPS-002), and both of those need the
 * same answer - "should this instance still be sent work" - without either of
 * them importing a health controller.
 *
 * `ObservabilityModule` is deliberately NOT imported here. It used to be, and
 * that made it reachable only through another `@Global()` module, which Nest
 * resolves by a different path than a first-class import: the app hung inside
 * `NestFactory.create` with no output at all, and removing the import produced
 * an immediate `UnknownDependenciesException` proving the service had been
 * resolving through this path rather than by global registration. It is now
 * imported by `AppModule` like any other top-level module, and the scrape route
 * `/health/metrics` still sits next to the probes an operator already knows
 * about because the controller is mounted by its own module, not by this one.
 */
@Global()
@Module({
  imports: [TerminusModule],
  controllers: [HealthController],
  providers: [ReadinessState],
  exports: [ReadinessState],
})
export class HealthModule {}
