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
