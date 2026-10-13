import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'crypto';
import { ShareTokenService } from './share-token.service';

const SECRET = 'a-test-secret';

// `null` rather than `undefined`, because an explicit `undefined` would take
// the default parameter and quietly test the happy path instead.
function service(secret: string | null = SECRET): ShareTokenService {
  return new ShareTokenService({
    get: (key: string) =>
      key === 'OTP_SECRET' ? (secret ?? undefined) : undefined,
  } as unknown as ConfigService);
}

describe('ShareTokenService', () => {
  const now = Date.UTC(2026, 9, 8, 12, 0, 0);

  describe('mint', () => {
    it('returns a token that verifies back to the same booking', () => {
      const tokens = service();
      const { token } = tokens.mint('booking-1', 3600, now);

      expect(tokens.verify(token, now)).toEqual({ bookingId: 'booking-1' });
    });

    it('reports when the link expires', () => {
      const { expiresAt } = service().mint('booking-1', 3600, now);

      expect(expiresAt.toISOString()).toBe('2026-10-08T13:00:00.000Z');
    });

    it('refuses a lifetime beyond the maximum', () => {
      const { expiresAt } = service().mint(
        'booking-1',
        ShareTokenService.maxTtlSeconds * 100,
        now,
      );

      expect(expiresAt.toISOString()).toBe('2026-10-09T12:00:00.000Z');
    });

    it('refuses a lifetime below the floor rather than minting a useless link', () => {
      const { expiresAt } = service().mint('booking-1', 1, now);

      expect(expiresAt.toISOString()).toBe('2026-10-08T12:01:00.000Z');
    });

    it('refuses an empty booking id', () => {
      expect(() => service().mint('', 3600, now)).toThrow(BadRequestException);
    });

    it('fails closed when the signing secret is not configured', () => {
      // An unconfigured secret must not mean an unsigned, forgeable link.
      expect(() => service(null).mint('booking-1', 3600, now)).toThrow(
        /OTP_SECRET/,
      );
    });
  });

  describe('verify', () => {
    it('rejects a tampered booking id', () => {
      const tokens = service();
      const { token } = tokens.mint('booking-1', 3600, now);
      const [payload, signature] = token.split('.') as [string, string];
      const forged = Buffer.from(
        JSON.stringify({ b: 'booking-2', exp: Math.floor(now / 1000) + 3600 }),
        'utf8',
      ).toString('base64url');

      // The signature still covers the original payload, so swapping the
      // payload invalidates the link. This is the whole point of signing.
      expect(() => tokens.verify(`${forged}.${signature}`, now)).toThrow(
        BadRequestException,
      );
      expect(payload).not.toBe(forged);
    });

    it('rejects a token signed with a different secret', () => {
      const other = new ShareTokenService({
        get: () => 'a-different-secret',
      } as unknown as ConfigService);
      const { token } = other.mint('booking-1', 3600, now);

      expect(() => service().verify(token, now)).toThrow(BadRequestException);
    });

    it('rejects an expired token', () => {
      const tokens = service();
      const { token } = tokens.mint('booking-1', 60, now);

      expect(() => tokens.verify(token, now + 61_000)).toThrow(
        BadRequestException,
      );
      expect(() => tokens.verify(token, now + 59_000)).not.toThrow();
    });

    it.each([
      ['empty', ''],
      ['no signature', 'abc'],
      ['too many parts', 'a.b.c'],
      ['empty payload', '.sig'],
      ['empty signature', 'payload.'],
      ['non-json payload', `${Buffer.from('nope').toString('base64url')}.sig`],
    ])('rejects a malformed token (%s)', (_label, token) => {
      expect(() => service().verify(token, now)).toThrow(BadRequestException);
    });

    it('rejects a well-signed token whose payload has the wrong shape', () => {
      const tokens = service();
      const payload = Buffer.from(
        JSON.stringify({ b: 'booking-1' }),
        'utf8',
      ).toString('base64url');
      const signature = createHmac('sha256', SECRET)
        .update(`share:${payload}`)
        .digest('base64url');

      expect(() => tokens.verify(`${payload}.${signature}`, now)).toThrow(
        BadRequestException,
      );
    });

    it('gives the same answer for every failure, so it leaks nothing', () => {
      const tokens = service();
      const messages = new Set<string>();
      for (const bad of ['', 'abc', 'a.b.c', tokens.mint('b', 60, now).token]) {
        try {
          tokens.verify(bad, now + 10 * 60_000);
        } catch (error) {
          messages.add((error as Error).message);
        }
      }

      // One message for malformed, tampered and expired alike: a caller cannot
      // use the error to tell which of the three it hit.
      expect(messages.size).toBe(1);
    });

    it('is domain-separated from the service-start OTP', () => {
      const tokens = service();
      const { token } = tokens.mint('booking-1', 3600, now);
      const [payload] = token.split('.') as [string];
      const otpStyle = createHmac('sha256', SECRET)
        .update(payload)
        .digest('base64url');

      // Same key, different HMAC input. Without the `share:` prefix a signature
      // minted for one purpose could satisfy the other.
      expect(() => tokens.verify(`${payload}.${otpStyle}`, now)).toThrow(
        BadRequestException,
      );
    });
  });
});
