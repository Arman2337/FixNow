# FixNow Admin

Next.js App Router application for authorized FixNow staff. Authentication is handled by server actions; access and refresh tokens are stored only in HTTP-only, strict same-site cookies. The backend remains authoritative for every permission decision.

## Prerequisites

- Node.js 20.9 or later
- npm 10 or later
- The FixNow backend running at the configured API URL

## Setup

```powershell
npm install
Copy-Item .env.example .env.local
npm run dev
```

Open `http://localhost:3100`. The default API URL is `http://localhost:3000/api/v1`. Production API URLs must use HTTPS.

Only active accounts with exactly one current staff role can establish an admin session. Customer and provider credentials receive the same safe sign-in failure as invalid credentials.

For controlled local reviewer testing, use the disposable reviewer fixture documented in [`../docs/testing/local-acceptance-fixtures.md`](../docs/testing/local-acceptance-fixtures.md). It grants only `provider_reviewer`; it is never a production credential or a provider self-approval path.

## Validation

```powershell
npm run lint
npm run type-check
npm test
npm run build
```
