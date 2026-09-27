# Contributing to FixNow

FixNow uses short-lived branches and pull-request review. Read [`AGENTS.md`](AGENTS.md) and the development documentation before contributing.

## Local setup

Activate the repository hooks after cloning:

```bash
git config core.hooksPath .githooks
```

Install the toolchain for the area you change. Backend work uses Node.js and npm;
mobile work uses Flutter and its platform prerequisites. Follow
[`backend/README.md`](backend/README.md) or
[`mobile/README.md`](mobile/README.md) for exact setup and validation commands.

## Contribution flow

1. Update local `main` with a fast-forward pull.
2. Create a branch using an approved prefix.
3. Make a focused change with appropriate tests and documentation.
4. Run relevant checks and inspect the staged diff.
5. Use Conventional Commits.
6. Open a pull request using the repository template.

See the [branching strategy](docs/development/branching-strategy.md) and [Git workflow](docs/development/git-workflow.md) for exact commands and policies.

## Database changes

Schema changes go through reviewed SQL migrations in `backend/migrations/`. Never
rely on `synchronize`; it is disabled on purpose and a running application must
never rewrite its own schema.

```bash
cd backend
npm run migration:show      # what is pending
npm run migration:run       # apply pending migrations
npm run schema:verify       # assert the schema's integrity invariants
npm run schema:verify:fresh # build a throwaway DB from every migration, then verify it
```

`schema:verify` asserts the things a migration can silently destroy: the
bookings foreign keys, the value-domain `CHECK` constraints, the `version`
column defaults, and the unique indexes that stop duplicate invoices, receipts
and refunds. It also proves the database actively refuses bad data.

**Run `schema:verify:fresh` whenever you add or change a migration.** A migration
once dropped every bookings foreign key, several `CHECK` constraints and the
`version` defaults without restoring them, and no test noticed. A database built
only by hand-editing never surfaces that class of bug; one built from the full
migration history does.

## Review expectations

Pull requests require passing checks and review from the owners matched by `.github/CODEOWNERS`. Security-sensitive, breaking, infrastructure, and architecture changes need explicit risk and rollout notes.

`.github/workflows/ci.yml` runs three jobs: `schema` (build from migrations,
then verify), `backend` (typecheck, lint, test), and `spec-types`, which reports
remaining test-file type errors without blocking a pull request. The
`spec-types` job is expected to reach zero and then be deleted.
