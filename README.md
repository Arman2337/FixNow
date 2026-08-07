# FixNow

FixNow is a planned multi-surface platform with a mobile client, backend services, an administrative web application, shared contracts, infrastructure definitions, and AI capabilities.

This repository currently contains only the engineering foundation. No Flutter, NestJS, Next.js, infrastructure, or AI application code has been generated.

## Repository layout

| Path | Intended ownership |
| --- | --- |
| `mobile/` | Future Flutter mobile application |
| `backend/` | Future NestJS services and APIs |
| `admin/` | Future Next.js administration application |
| `shared/` | Cross-project contracts, schemas, and tooling |
| `infrastructure/` | Deployment and infrastructure-as-code definitions |
| `ai/` | AI services, evaluation assets, and supporting tools |
| `docs/` | Architecture, workflow, and engineering documentation |

Each empty project directory contains a `.gitkeep` file so Git preserves the intended structure. Replace it when real files are introduced.

## Getting started

1. Install Git 2.28 or later.
2. Clone the repository.
3. Activate the version-controlled hooks:

   ```bash
   git config core.hooksPath .githooks
   ```

4. Create a branch before making changes:

   ```bash
   git switch -c feat/short-description
   ```

5. Copy `.env.example` to an untracked `.env` only when local configuration is needed.

Technology-specific setup will be added when each application is bootstrapped.

## Development rules

- Never commit directly to `main`; the pre-commit hook enforces this locally.
- Keep secrets out of Git. Commit placeholders only in `.env.example`.
- Use small pull requests with tests and documentation proportional to the change.
- Do not create dependencies between applications through internal file imports. Put stable shared contracts in `shared/`.
- Record material architecture decisions in `docs/architecture/decisions/`.

## Documentation

- [Architecture](docs/architecture/README.md)
- [Branching strategy](docs/development/branching-strategy.md)
- [Git workflow](docs/development/git-workflow.md)
- [AI agent rules](AGENTS.md)
- [Claude guidance](CLAUDE.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## Status

Foundation only. Product implementation is intentionally out of scope for this initial revision.

## License

No license has been selected. All rights are reserved until the repository owners add one.
