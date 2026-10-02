import { Injectable, NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { ConfigService } from '@nestjs/config';
import { Environment } from '../../config/env.validation';

/**
 * The baseline headers helmet would set, minus the ones this app must not send.
 *
 * OPS-003. helmet is not a dependency here and the repository does not install
 * packages without approval, so the small set this service actually needs is
 * set directly. If helmet is ever adopted, delete this file rather than running
 * both - duplicated headers are a common source of confusing conflicts.
 *
 * Deliberately absent:
 *
 * - `Cross-Origin-Embedder-Policy` and `Cross-Origin-Opener-Policy`: this is a
 *   JSON API, and COEP breaks cross-origin fetches the web client relies on.
 * - `X-XSS-Protection`: removed from modern browsers as a vector rather than a
 *   defence, and historically introduced its own bugs.
 */
const DEFAULT_CSP = [
  "default-src 'none'",
  "frame-ancestors 'none'",
  "base-uri 'none'",
  "form-action 'none'",
].join('; ');

@Injectable()
export class SecurityHeadersMiddleware implements NestMiddleware {
  private readonly csp: string;
  private readonly hstsMaxAge: number | null;

  constructor(private readonly config: ConfigService) {
    const configured = this.config.get<string>('CSP_DIRECTIVES')?.trim();
    this.csp = configured || DEFAULT_CSP;

    const maxAge = this.config.get<number>('HSTS_MAX_AGE_SECONDS');
    // HSTS on a plain-HTTP origin locks the browser out of that origin for the
    // full max-age, so it is production-only rather than merely default-on.
    this.hstsMaxAge =
      this.config.get<Environment>('NODE_ENV') === Environment.Production &&
      typeof maxAge === 'number' &&
      maxAge > 0
        ? maxAge
        : null;
  }

  use(req: Request, res: Response, next: NextFunction): void {
    res.setHeader('Content-Security-Policy', this.csp);
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader(
      'Permissions-Policy',
      'camera=(), microphone=(), geolocation=(), payment=()',
    );
    res.removeHeader('X-Powered-By');

    if (this.hstsMaxAge !== null) {
      res.setHeader(
        'Strict-Transport-Security',
        `max-age=${this.hstsMaxAge}; includeSubDomains`,
      );
    }

    next();
  }
}
