# Local acceptance fixtures

The backend provides an explicit, disposable fixture path for controlled local
marketplace testing. It creates synthetic Customer A, Provider A, Provider B,
and a least-privilege provider reviewer. These identities authenticate through
the normal customer, provider, and admin login endpoints; the fixture script is
not an application backdoor.

Run only against the isolated loopback `fixnow_dev` or `fixnow_test` database:

```powershell
cd backend
$env:NODE_ENV = "development"
$env:ACCEPTANCE_FIXTURES_ENABLED = "true"
$env:DATABASE_URL = "postgresql://fixnow_dev:fixnow_dev@127.0.0.1:55432/fixnow_dev"
npm run test:acceptance:seed
```

For the isolated integration database, set `TEST_DATABASE_URL` instead. The
script refuses production, shared, non-loopback, or unapproved database names,
and it requires the explicit fixture flag.

The command is idempotent for the fixture identities: it removes the previous
synthetic identities first, then recreates them. Remove them when finished:

```powershell
npm run test:acceptance:cleanup
```

Synthetic credentials:

| Identity | Email | Password |
| --- | --- | --- |
| Customer A | `fixnow.acceptance.customer-a@local.test` | `FixNow-local-customer-a-2026!` |
| Provider A | `fixnow.acceptance.provider-a@local.test` | `FixNow-local-provider-a-2026!` |
| Provider B | `fixnow.acceptance.provider-b@local.test` | `FixNow-local-provider-b-2026!` |
| Reviewer | `fixnow.acceptance.reviewer@local.test` | `FixNow-local-reviewer-2026!` |

Provider A is approved, verified, skilled for Plumbing, online, and positioned
near the local acceptance coordinates. Provider B is also verified and online
but positioned outside Provider A's service scenario for negative matching
tests. The reviewer has only the `provider_reviewer` role and cannot approve
their own provider application. No real identity documents or personal data
are created.
