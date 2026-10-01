import { Global, Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health.controller';
import { ReadinessState } from './readiness-state.service';

/**
 * Global, because the drain signal and dependency degradation are not the
 * health module's business alone. The cache module reports a Redis outage
 * (BUG-012) and `main.ts` starts the drain (OPS-002), and both of those need
 * the same answer - "should this instance still be sent work" - without either
 * of them importing a health controller.
 */
@Global()
@Module({
  imports: [TerminusModule],
  controllers: [HealthController],
  providers: [ReadinessState],
  exports: [ReadinessState],
})
export class HealthModule {}
