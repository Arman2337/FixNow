import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EnvironmentVariables } from '../../config/env.validation';

/**
 * Decides whether a customer-supplied link may be stored and later rendered in
 * a trusted surface.
 *
 * Complaint evidence arrives as a URL in the request body and is displayed in
 * the support-agent console. With no check, a customer could file a complaint
 * whose "evidence" is `https://fixnow-support-verify.example/login`, and the
 * agent opening the case is the one phished. Restricting evidence to FixNow's
 * own origins removes the primitive without inventing an upload pipeline.
 *
 * A URL is trusted when it is https, carries no embedded credentials, and its
 * origin is listed in `EVIDENCE_ALLOWED_ORIGINS`, falling back to
 * `WEB_ALLOWED_ORIGINS` so the two stay in step.
 *
 * Note the deliberate asymmetry with the photo and document paths: those accept
 * uploaded bytes, quarantine them, magic-byte check and malware scan them, and
 * store a server-generated object key. Nothing fetches these URLs server-side,
 * so this is an outbound-phishing control, not an SSRF control.
 */
@Injectable()
export class TrustedEvidenceUrl {
  private readonly allowedOrigins: ReadonlySet<string>;

  constructor(config: ConfigService<EnvironmentVariables, true>) {
    const configured =
      config.get<string>('EVIDENCE_ALLOWED_ORIGINS') ??
      config.get<string>('WEB_ALLOWED_ORIGINS') ??
      '';
    this.allowedOrigins = new Set(
      configured
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean)
        .map((value) => this.originOf(value))
        .filter((value): value is string => value !== null),
    );
  }

  /** Number of configured origins; 0 means every link will be refused. */
  get configuredOriginCount(): number {
    return this.allowedOrigins.size;
  }

  private originOf(value: string): string | null {
    try {
      return new URL(value).origin;
    } catch {
      return null;
    }
  }

  isTrusted(rawUrl: string): boolean {
    let url: URL;
    try {
      url = new URL(rawUrl);
    } catch {
      return false;
    }
    if (url.protocol !== 'https:') return false;
    if (url.username || url.password) return false;
    return this.allowedOrigins.has(url.origin);
  }

  /**
   * @throws BadRequestException when the link is not one of ours, so the
   * reason is never stored or echoed back into the support console.
   */
  assertTrusted(rawUrl: string, field = 'fileUrl'): void {
    if (!this.isTrusted(rawUrl)) {
      throw new BadRequestException(
        `${field} must be an https link on an approved FixNow origin`,
      );
    }
  }
}
