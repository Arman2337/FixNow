import { Controller, Get, Res } from '@nestjs/common';
import type { Response } from 'express';
import { ObservabilityService } from './observability.service';
import { Public } from '../common/authorization/authorization.decorators';

/**
 * The scrape endpoint, served at `/health/metrics`.
 *
 * Mounted under `health` rather than at a bare `/metrics` so it sits next to the
 * probes an operator already knows about, and is unambiguously not an API route.
 *
 * `@Public()` because a Prometheus scraper has no FixNow credential, and the
 * alternative — a bearer token in the scrape config — makes the metrics endpoint
 * the one thing that fails exactly when the auth path is what is broken.
 *
 * What it exposes is deliberately not sensitive: counts, durations and dependency
 * health. There are no customer identifiers, no booking ids, no amounts, and no
 * route parameters — every label is either a route template, a method, a status
 * class, or a fixed category. A metrics endpoint that leaked user ids would be a
 * data breach with a scrape config attached to it.
 */
@Controller('health/metrics')
export class MetricsController {
  constructor(private readonly observability: ObservabilityService) {}

  @Public()
  @Get()
  scrape(@Res() response: Response): void {
    response.setHeader(
      'Content-Type',
      'text/plain; version=0.0.4; charset=utf-8',
    );
    // Scrapes must never be cached: a stale reading is worse than no reading,
    // because it looks like data.
    response.setHeader('Cache-Control', 'no-store');
    response.status(200).send(this.observability.render());
  }
}
