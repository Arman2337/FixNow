# Branching strategy

FixNow uses trunk-based development with short-lived branches and pull requests into `main`.

## Protected branch

`main` is always expected to be releasable. Direct commits are prohibited. Configure hosting protection to require pull requests, required status checks, resolved conversations, and CODEOWNER approval where applicable. The local pre-commit hook is a convenience guard, not a substitute for server-side protection.

## Branch naming

Use lowercase kebab-case after one of these prefixes:

| Prefix | Purpose | Example |
| --- | --- | --- |
| `feat/` | New capability | `feat/provider-onboarding` |
| `fix/` | Defect correction | `fix/session-timeout` |
| `chore/` | Maintenance or tooling | `chore/update-lint-config` |
| `docs/` | Documentation only | `docs/api-conventions` |
| `refactor/` | Behavior-preserving structure change | `refactor/job-dispatch` |
| `test/` | Test-only work | `test/payment-boundaries` |
| `hotfix/` | Urgent production correction | `hotfix/auth-regression` |

Include an issue identifier when one exists, for example `fix/123-session-timeout`.

## Lifecycle

1. Create a branch from current `main`.
2. Commit small, coherent changes using Conventional Commits.
3. Push the branch and open a pull request early enough for useful review.
4. Keep the branch current by rebasing on `main` before merge when repository policy allows it.
5. Merge only after required checks and reviews pass.
6. Delete the merged branch from the remote and local clone.

Branches should normally live for days, not weeks. Split large work behind stable contracts or feature flags rather than maintaining long-running integration branches.

## Merge policy

Prefer squash merge for a focused pull request so `main` retains a readable history. The squash message must follow Conventional Commits. Use a regular merge only when preserving meaningful commit structure is explicitly valuable. Do not force-push `main`.

## Releases and hotfixes

Create releases from `main` using annotated semantic-version tags once release automation exists. A hotfix starts from the production commit, receives expedited but required review, and merges back into `main` so the fix is not lost.
