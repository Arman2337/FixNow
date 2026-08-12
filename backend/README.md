# FixNow backend

NestJS backend foundation for FixNow. It provides validated configuration, structured logging, PostgreSQL/TypeORM wiring, Redis-backed cache fallback, health endpoints, and domain modules as tracked in `PROJECT_TASKS.md`.

## Prerequisites

- Node.js 24.x or a compatible supported release
- npm
- PostgreSQL 16 for migration and integration validation
- Redis 7 when exercising Redis-backed behavior

## Setup

From `backend/`:

```bash
npm ci
```

Copy the repository root `.env.example` to an untracked `backend/.env` only when running the application locally. Replace every placeholder locally; never commit credentials.

## Checks

```bash
npm run lint
npm test -- --runInBand
npm run build
```

Unit tests are deterministic and do not connect to developer services. Integration and end-to-end tests must use explicitly isolated local test services and synthetic data.

## Isolated PostgreSQL migration validation

The following disposable container binds only to loopback on port `55432`, avoiding the normal local development database on port `5432`. The values are test-only placeholders.

```bash
docker run --rm -d --name fixnow-postgres-test -e POSTGRES_USER=fixnow_test -e POSTGRES_PASSWORD=fixnow_test -e POSTGRES_DB=fixnow_test -p 127.0.0.1:55432:5432 postgres:16-alpine
```

Wait for PostgreSQL readiness, set `DATABASE_URL` in the current shell to `postgresql://fixnow_test:fixnow_test@127.0.0.1:55432/fixnow_test`, then validate both migration directions:

```bash
node -r ts-node/register -r tsconfig-paths/register node_modules/typeorm/cli.js migration:run -d typeorm.config.ts
node -r ts-node/register -r tsconfig-paths/register node_modules/typeorm/cli.js migration:revert -d typeorm.config.ts
node -r ts-node/register -r tsconfig-paths/register node_modules/typeorm/cli.js migration:run -d typeorm.config.ts
```

With `TEST_DATABASE_URL` set to the same isolated database, run repository and constraint integration tests:

```bash
npm run test:integration
```

Stop the disposable service after validation:

```bash
docker stop fixnow-postgres-test
```

Never point automated tests or migration validation at a shared, staging, or production database.

## Run locally

```bash
npm run start:dev
```

The API uses the `/api/v1` prefix. Health endpoints are available under that prefix once the application is running.

## Customer authentication

FN-024 provides `POST /api/v1/auth/customer/register` and `POST /api/v1/auth/customer/login`. Both accept a normalized email and a 12–128 character password. Passwords are stored only as Argon2id hashes, and successful responses contain a short-lived bearer access token. Configure `JWT_SECRET` with at least 32 random characters outside source control. OTP, refresh-token lifecycle, and password recovery are not part of these endpoints.

FN-025 adds `POST /api/v1/auth/provider/register` with the same credential boundary. It creates only a `provider_applicant` role and an `unverified` onboarding record. The endpoint does not accept lifecycle status or role input and cannot approve a provider or collect KYC documents.

## OTP email and sessions

FN-026 adds these endpoints:

- `POST /api/v1/auth/otp/request`
- `POST /api/v1/auth/otp/verify`
- `POST /api/v1/auth/token/refresh`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/logout-all`

OTP messages go to the email address registered with the account. Configure a separate `OTP_SECRET` of at least 32 random characters. For real email delivery, set `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, and `SMTP_FROM` in an untracked local `.env`. Gmail can use `smtp.gmail.com`; use an account-specific app password rather than a normal account password. Automated tests use a fake delivery adapter and never send email.

OTPs expire after 10 minutes, enforce a 60-second resend delay, and allow five attempts. Refresh tokens expire after 30 days, rotate once without grace, and revoke the token family if an already-rotated token is replayed. Raw OTPs and refresh tokens are never stored.

## Customer profile

FN-028 adds authenticated self-service profile endpoints:

- `GET /api/v1/users/me/profile`
- `PATCH /api/v1/users/me/profile`

The initial profile contract contains only `displayName`, a trimmed string from 1 to 80 characters. Ownership is derived from the validated access token; clients cannot select another user ID. Profile reads and updates are audited without recording the display-name value. Additional personal data is intentionally not collected.

## Provider profile and service area

FN-030 adds provider-applicant self-service endpoints:

- `GET /api/v1/provider-profile/me`
- `PUT /api/v1/provider-profile/me`
- `PUT /api/v1/provider-profile/me/coverage-check`

Profiles contain a display name, optional biography, service radius, base
coordinates, and service-category skills. The coverage-check response reports
only whether a coordinate is within the provider's configured radius; it does
not disclose the provider's private base coordinates.

## Provider documents

FN-031 adds provider-applicant self-service endpoints:

- `POST /api/v1/provider-documents/:documentType`
- `GET /api/v1/provider-documents/:id`
- `DELETE /api/v1/provider-documents/:id`

Upload one file in the multipart `document` field. Supported document types are
`identity`, `license`, and `certification`; uploads are limited to 10 MiB and
remain unavailable until malware scanning succeeds. Objects use private opaque
keys and are returned only through the authorized download endpoint. For the
development-only SeaweedFS and ClamAV setup, see
[`../infrastructure/local/README.md`](../infrastructure/local/README.md).

## Provider verification

FN-032 adds authorized reviewer endpoints:

- `POST /api/v1/provider-verification/:applicationId/claim`
- `POST /api/v1/provider-verification/:applicationId/decision`

Both mutations require the application's expected version. Only the assigned
reviewer can record a decision, every decision requires a reason, and approval
atomically activates the provider account and grants the verified-provider role.
The local document stack is not approved for real KYC or production processing.

## Provider availability

FN-033 adds verified-provider self-service endpoints:

- `GET /api/v1/provider-availability/me`
- `PUT /api/v1/provider-availability/me/schedule`
- `PUT /api/v1/provider-availability/me/status`

Schedules use an explicit IANA time zone, weekly intervals expressed as local
minutes after midnight, and date-specific exceptions. Intervals cannot overlap
or cross midnight; split overnight availability across two days. Online and
busy status must include an expiry no more than 12 hours in the future and
automatically reads as offline after expiry. Mutations require the current
`version` so stale concurrent updates are rejected.

## Booking lifecycle

FN-038 through FN-042 provide authenticated booking endpoints under
`/api/v1/bookings`:

- `POST /api/v1/bookings` requires an `Idempotency-Key` header containing 8–128
  safe characters. Reusing a key with an identical request returns the original
  booking; reusing it with a different request returns a conflict.
- `POST /api/v1/bookings/:id/accept`, `PATCH /api/v1/bookings/:id/status`, and
  `POST /api/v1/bookings/:id/cancel` require `expectedVersion`. Stale or racing
  commands return a conflict.
- `GET /api/v1/bookings?limit=20&cursor=...` returns stable cursor pagination.
  Exact booking coordinates are removed from provider history responses.

Provider acceptance is limited to active, online, non-expired providers with a
verified skill, active category, and matching service radius. Lifecycle changes
are atomic and append database-immutable audit events. Payment, refunds,
ratings, and live tracking remain outside these tasks.

## Authenticated real-time connections

FN-043 adds the WebSocket endpoint at `/realtime`. Shared environments must use
TLS (`wss://`). Browser origins are deny-by-default and must be listed as
comma-separated HTTPS origins in `REALTIME_ALLOWED_ORIGINS`; loopback HTTP is
accepted only outside production for local development.

The client sends authentication as its first text frame so credentials never
appear in a URL:

```json
{"type":"authenticate","accessToken":"<short-lived access token>"}
```

After the `ready` frame, a client may subscribe only to allowlisted semantic
channels. FN-043 exposes the self-owned `account` channel as the authorization
foundation; booking and live-location projections remain owned by FN-045.
Subscriptions are re-authorized against the current session, account, and role
state. Reconnects do not imply replay: a request containing `afterSequence`
receives `snapshot-required`, and the authenticated HTTP API remains the source
of truth.

The gateway enforces a 16 KiB text-frame limit, a five-second authentication
deadline, three connections per principal, ten subscriptions per connection,
thirty client messages per minute, browser-origin validation, and a 30-second
ping/pong heartbeat. Limits are conservative initial safety boundaries and must
be measured before scale changes. Frames, tokens, resource IDs, and payloads are
excluded from telemetry; only bounded outcome counters are recorded.

## Provider presence and live-location ingestion

FN-044 adds authenticated provider frames on `/realtime`:

- `presence-update` creates or clears a short Redis presence lease. It requires
  verified-provider role and current non-expired online/busy availability.
- `location-consent` records versioned, booking-scoped ephemeral consent or
  immediately invalidates consent and the latest point on withdrawal.
- `location-update` accepts a bounded point only from the provider assigned to
  a booking currently in `EN_ROUTE`, with current presence and consent.

Coordinates, accuracy, client time, monotonic sequence, freshness, ownership,
and rate are validated server-side. Only the latest operational point is cached
for at most the stale threshold; no raw route/history is stored. Going offline
invalidates active consent and location state. Customer location projections
and the “Live location unavailable” presentation remain FN-045; the service
exposes invalidation semantics for that projection.

`LOCATION_UPDATE_INTERVAL_MS` is limited to 10–15 seconds. The initial
`LOCATION_STALE_AFTER_MS` and maximum `LOCATION_CACHE_TTL_MS` are 60 seconds;
cache TTL cannot exceed the stale threshold. Presence TTL, consent TTL, maximum
accepted accuracy, and notice version are also centralized in validated
configuration. These values must remain within the approved OD-010 policy.
