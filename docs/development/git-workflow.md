# Git workflow

This guide describes the day-to-day contribution flow and the safeguards around `main`.

## Prerequisites

- Git 2.28 or later
- Access to the repository
- A configured Git author name and email

## One-time setup

After cloning, activate the tracked hooks:

```bash
git config core.hooksPath .githooks
```

Confirm the setting:

```bash
git config --get core.hooksPath
```

Expected output is `.githooks`.

## Start a change

Update `main` without creating a merge commit, then create a branch:

```bash
git switch main
git pull --ff-only
git switch -c feat/short-description
```

Use the prefix rules in the [branching strategy](branching-strategy.md).

## Review and commit locally

Inspect changes before staging:

```bash
git status --short
git diff
```

Stage files intentionally and inspect the exact commit content:

```bash
git add path/to/file
git diff --cached
```

Commit using an imperative Conventional Commit message:

```bash
git commit -m "feat(scope): describe the outcome"
```

Common types are `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, and `chore`.

## Synchronize safely

Before opening or updating a pull request:

```bash
git fetch origin
git rebase origin/main
```

Resolve conflicts carefully, rerun checks, and use `git push --force-with-lease` only on your own reviewed feature branch when rebasing requires it. Never force-push `main` or another contributor's branch.

## Open and merge a pull request

Push the branch, open a pull request using the template, and provide exact verification evidence. Merge only after required checks, approvals, and conversations are complete.

After merge:

```bash
git switch main
git pull --ff-only
git branch -d feat/short-description
```

## Hook behavior

`.githooks/pre-commit` rejects a commit whenever the checked-out branch is `main`. If it triggers, create a branch and retry:

```bash
git switch -c chore/short-description
git commit
```

Do not bypass the hook with `--no-verify`. If emergency policy requires a direct commit, an authorized maintainer must document and approve the exception, and server-side branch rules remain authoritative.

## Troubleshooting

### The hook does not run

Reapply and inspect the configuration:

```bash
git config core.hooksPath .githooks
git config --get core.hooksPath
```

On Unix-like systems, ensure the hook is executable with `chmod +x .githooks/pre-commit`.

### A rebase has conflicts

Resolve each file, stage it, and continue with `git rebase --continue`. To abandon the rebase safely, run `git rebase --abort`. Never use a hard reset to discard unreviewed work.
