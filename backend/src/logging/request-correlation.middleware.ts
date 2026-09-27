import { Injectable, NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { CORRELATION_HEADER } from './request-correlation';

/**
 * Echoes the correlation id back to the caller.
 *
 * A09 flagged the absence of a request correlation id, and the practical cost
 * is that a user reporting "it failed" gives us nothing to search on. Every
 * log line for the request already carries `reqId`; this makes that id visible
 * to the client so it can be quoted, and so support can pivot straight to it.
 */
@Injectable()
export class RequestCorrelationMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction): void {
    // Set by pino-http via genReqId in the logger module, so this is the same
    // value that appears on every log line for this request.
    const id = (req as Request & { id?: unknown }).id;
    if (typeof id === 'string' && id) {
      res.setHeader(CORRELATION_HEADER, id);
    }
    next();
  }
}
