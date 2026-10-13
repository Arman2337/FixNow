import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, timingSafeEqual } from 'crypto';

/**
 * FN-145. A capability token for a shared, read-only live-ETA view.
 *
 * Shape: `base64url(payloadJson).base64url(hmac)`, where the payload is
 * `{ b: bookingId, exp: unixSeconds }`. Stateless, so revoking a single share
 * would need a denylist — which is the honest trade-off for a link whose only
 * job is to show somebody "your pro is 6 minutes away" for an hour.
 *
 * Three properties this design is built around:
 *
 * 1. **Signed, never guessed.** The signature is over the payload, so a caller
 *    cannot swap the booking id in a link they were given for a different job.
 * 2. **Expiring.** A leaked link in a chat history stops working on its own.
 * 3. **Domain-separated.** The HMAC input is prefixed `share:`, so a token
 *    minted here can never collide with the service-start OTP, which is the
 *    same HMAC key over a different message shape. Reusing the configured
 *    secret this way is deliberate: a share link is not secret material, and a
 *    new environment variable would be a new thing to rotate, declare and
 *    deploy.
 */
@Injectable()
export class ShareTokenService {
  constructor(private readonly config: ConfigService) {}

  /** Bounded so a link can never become a permanent capability. */
  static readonly maxTtlSeconds = 24 * 60 * 60;

  mint(
    bookingId: string,
    ttlSeconds: number,
    now = Date.now(),
  ): { token: string; expiresAt: Date } {
    if (!bookingId) throw new BadRequestException('A booking is required');
    const ttl = Math.min(
      Math.max(Math.floor(ttlSeconds), 60),
      ShareTokenService.maxTtlSeconds,
    );
    const expiresAtSeconds = Math.floor(now / 1000) + ttl;
    const payload = Buffer.from(
      JSON.stringify({ b: bookingId, exp: expiresAtSeconds }),
      'utf8',
    ).toString('base64url');
    return {
      token: `${payload}.${this.sign(payload)}`,
      expiresAt: new Date(expiresAtSeconds * 1000),
    };
  }

  /**
   * Verify a token and return the booking it names.
   *
   * Every failure — malformed, tampered, expired — is the same `BadRequest`,
   * so a caller cannot use the error to learn which of the three it was.
   */
  verify(token: string, now = Date.now()): { bookingId: string } {
    const parts = String(token ?? '').split('.');
    if (parts.length !== 2 || !parts[0] || !parts[1]) {
      throw this.invalid();
    }
    const [payload, signature] = parts as [string, string];
    const expected = this.sign(payload);
    // Constant-time: a length- or prefix-dependent comparison would let a
    // caller recover the signature one byte at a time.
    if (
      signature.length !== expected.length ||
      !timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
    ) {
      throw this.invalid();
    }
    let decoded: unknown;
    try {
      decoded = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    } catch {
      throw this.invalid();
    }
    if (typeof decoded !== 'object' || decoded === null) throw this.invalid();
    const { b, exp } = decoded as { b?: unknown; exp?: unknown };
    if (typeof b !== 'string' || !b || typeof exp !== 'number') {
      throw this.invalid();
    }
    if (exp * 1000 <= now) throw this.invalid();
    return { bookingId: b };
  }

  private sign(payload: string): string {
    const secret = this.config.get<string>('OTP_SECRET');
    if (!secret) {
      // Failing closed is the only safe answer: an unconfigured secret would
      // otherwise mean an unsigned, forgeable link.
      throw new Error('OTP_SECRET is not configured');
    }
    return createHmac('sha256', secret)
      .update(`share:${payload}`)
      .digest('base64url');
  }

  private invalid(): BadRequestException {
    return new BadRequestException('This share link is invalid or has expired');
  }
}
