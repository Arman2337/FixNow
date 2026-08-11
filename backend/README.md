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
