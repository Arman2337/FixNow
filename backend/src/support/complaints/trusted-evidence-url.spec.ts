import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TrustedEvidenceUrl } from './trusted-evidence-url';

function build(allowed?: string): TrustedEvidenceUrl {
  const config = {
    get: (key: string) =>
      key === 'EVIDENCE_ALLOWED_ORIGINS'
        ? allowed
        : allowed === undefined
          ? 'https://app.fixnow.test'
          : undefined,
  } as unknown as ConfigService<never, true>;
  return new TrustedEvidenceUrl(config);
}

describe('TrustedEvidenceUrl', () => {
  describe('accepts links on an approved origin', () => {
    it('accepts https on a configured origin', () => {
      const guard = build('https://cdn.fixnow.test');
      expect(guard.isTrusted('https://cdn.fixnow.test/evidence/a.png')).toBe(
        true,
      );
    });

    it('accepts a deep path and query on that origin', () => {
      const guard = build('https://cdn.fixnow.test');
      expect(guard.isTrusted('https://cdn.fixnow.test/a/b/c.png?sig=xyz')).toBe(
        true,
      );
    });

    it('accepts when several origins are configured', () => {
      const guard = build('https://a.fixnow.test, https://b.fixnow.test');
      expect(guard.isTrusted('https://b.fixnow.test/x.png')).toBe(true);
    });

    it('falls back to WEB_ALLOWED_ORIGINS when none is set', () => {
      const guard = build(undefined);
      expect(guard.isTrusted('https://app.fixnow.test/x.png')).toBe(true);
    });
  });

  describe('refuses links that could phish a support agent', () => {
    it('refuses an attacker-controlled host', () => {
      const guard = build('https://cdn.fixnow.test');
      expect(
        guard.isTrusted('https://fixnow-evidence-verify.example/login'),
      ).toBe(false);
    });

    it('refuses a lookalike host that merely contains ours', () => {
      const guard = build('https://cdn.fixnow.test');
      expect(guard.isTrusted('https://cdn.fixnow.test.evil.example/x')).toBe(
        false,
      );
      expect(guard.isTrusted('https://evil-cdn.fixnow.test.attacker.io')).toBe(
        false,
      );
    });

    it('refuses plain http even on an approved host', () => {
      const guard = build('https://cdn.fixnow.test');
      expect(guard.isTrusted('http://cdn.fixnow.test/x.png')).toBe(false);
    });

    it('refuses javascript: and data: payloads', () => {
      const guard = build('https://cdn.fixnow.test');
      expect(guard.isTrusted('javascript:alert(1)')).toBe(false);
      expect(guard.isTrusted('data:text/html,<script>alert(1)</script>')).toBe(
        false,
      );
    });

    it('refuses credentials embedded in the URL', () => {
      const guard = build('https://cdn.fixnow.test');
      expect(guard.isTrusted('https://user:pass@cdn.fixnow.test/x.png')).toBe(
        false,
      );
    });

    it('refuses a malformed or relative value', () => {
      const guard = build('https://cdn.fixnow.test');
      expect(guard.isTrusted('not a url')).toBe(false);
      expect(guard.isTrusted('/relative/path.png')).toBe(false);
    });
  });

  describe('when no origins are configured', () => {
    it('refuses everything rather than trusting the open internet', () => {
      const guard = build('');
      expect(guard.configuredOriginCount).toBe(0);
      expect(guard.isTrusted('https://anything.example/x.png')).toBe(false);
    });
  });

  describe('assertTrusted', () => {
    it('throws a BadRequest naming the field, not the value', () => {
      const guard = build('https://cdn.fixnow.test');
      expect(() => guard.assertTrusted('https://evil.example/x')).toThrow(
        BadRequestException,
      );
      try {
        guard.assertTrusted(
          'https://evil.example/secret-token',
          'evidence[].fileUrl',
        );
      } catch (e) {
        const message = (e as Error).message;
        expect(message).toContain('evidence[].fileUrl');
        // The offending value must not be echoed back into logs or a response.
        expect(message).not.toContain('secret-token');
      }
    });

    it('stays quiet for a trusted link', () => {
      const guard = build('https://cdn.fixnow.test');
      expect(() =>
        guard.assertTrusted('https://cdn.fixnow.test/x.png'),
      ).not.toThrow();
    });
  });
});
