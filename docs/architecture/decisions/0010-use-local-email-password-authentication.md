# ADR-0010: Use local email and password authentication

- Status: Accepted
- Date: 2026-08-11
- Owners: Product, Security, Engineering

## Context

FN-024 requires customer registration and login, while OD-005 previously left the authentication mechanism unresolved. The first release needs a provider-independent path that works in local and test environments without external credentials. Authentication failures must resist account enumeration, credentials must never be stored or logged in plaintext, and later OTP and refresh-token work must remain independently deliverable under FN-026.

## Decision

- Customers register with a normalized lowercase email address and a password.
- Passwords are hashed with Argon2id using the maintained `argon2` library. Only the encoded hash is stored in a credential table separate from profile data.
- Successful login returns a short-lived, audience- and issuer-bound JWT access token signed with an environment-provided secret. Access tokens expire after 15 minutes by default.
- Login failures use one generic response for unknown identities and invalid passwords. Registration conflicts use a generic account-creation conflict.
- Registration and login are throttled independently. Limits are initial abuse boundaries, not a complete production anti-abuse system.
- Newly registered accounts remain `pending_verification`; authorization must continue to enforce account state.
- OTP verification, refresh-token rotation/revocation, password recovery, and external identity providers are outside FN-024 and remain scoped to later tasks, including FN-026.

## Consequences

Local development requires no identity-provider account. The backend must protect and rotate the JWT signing secret, and a future asymmetric or managed signing design may supersede this decision. Email ownership is not established until a later verification flow. Database migration is required for credential storage.

## Alternatives considered

- A hosted identity provider was deferred because no provider, commercial terms, or external account has been approved.
- Phone/OTP-only authentication was deferred to FN-026 because delivery-provider and verification policy are unresolved.
- Reversible password encryption was rejected because the backend does not need to recover plaintext credentials.

## Validation

Tests cover successful registration/login, normalized duplicate identities, invalid input, generic authentication failures, Argon2id verification, JWT claims/expiry, and endpoint throttling. Reconsider this ADR if product requirements mandate federation, passwordless-only authentication, or centrally managed signing keys.
