# Contributing to FixNow

FixNow uses short-lived branches and pull-request review. Read [`AGENTS.md`](AGENTS.md) and the development documentation before contributing.

## Local setup

Activate the repository hooks after cloning:

```bash
git config core.hooksPath .githooks
```

No application toolchain is required yet because this revision contains foundation files only.

## Contribution flow

1. Update local `main` with a fast-forward pull.
2. Create a branch using an approved prefix.
3. Make a focused change with appropriate tests and documentation.
4. Run relevant checks and inspect the staged diff.
5. Use Conventional Commits.
6. Open a pull request using the repository template.

See the [branching strategy](docs/development/branching-strategy.md) and [Git workflow](docs/development/git-workflow.md) for exact commands and policies.

## Review expectations

Pull requests require passing checks and review from the owners matched by `.github/CODEOWNERS`. Security-sensitive, breaking, infrastructure, and architecture changes need explicit risk and rollout notes.
