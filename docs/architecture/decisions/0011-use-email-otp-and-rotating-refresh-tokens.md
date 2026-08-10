# ADR-0011: Use email OTP and rotating refresh tokens

- Status: Accepted
- Date: 2026-08-11
- Owners: Product, Security, Engineering

## Context

FN-026 requires email ownership verification and renewable, revocable sessions without storing raw OTPs or refresh tokens. Live email credentials must remain outside source control, while automated validation must be deterministic and provider-independent.

## Decision

Verification codes are delivered to the registered email through a configurable SMTP adapter. Gmail SMTP is supported through configuration, but no provider credential is committed. Automated tests inject a fake delivery adapter.

OTPs expire after 10 minutes, may be resent after 60 seconds, and allow five verification attempts. Codes are stored only as keyed SHA-256 hashes using a separate environment secret.

Refresh tokens are opaque 256-bit random values with a 30-day lifetime. Only SHA-256 token hashes are stored. Every refresh rotates the token with no grace period. Reuse of a rotated token revokes its entire token family. Logout revokes the current session; logout-all revokes all active sessions for the account. Lifecycle events persist minimal audit classifications without tokens, OTPs, or email addresses.

## Consequences

Real email delivery requires locally supplied SMTP configuration. A compromised refresh token is bounded by one-time rotation and family revocation, but clients must replace stored tokens atomically. SMTP availability can temporarily prevent new verification messages without weakening existing sessions.

## Alternatives considered

SMS OTP was deferred because no phone-verification policy or provider is approved. JWT refresh tokens were rejected because opaque random tokens simplify server-side rotation and immediate revocation. Rotation grace was rejected because it weakens replay detection.

## Validation

Tests cover OTP expiry, resend, brute-force exhaustion, one-time use, refresh expiry, rotation, replay-family revocation, current-session logout, logout-all, safe audit data, migration rollback, and SMTP configuration failure.
