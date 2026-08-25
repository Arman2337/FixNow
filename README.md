# FixNow

FixNow is a planned multi-surface platform with a mobile client, backend services, an administrative web application, shared contracts, infrastructure definitions, and AI capabilities.

This repository contains the engineering foundation, a NestJS backend, a Flutter mobile application, and a Next.js administrative web foundation. Product features remain tracked in `PROJECT_TASKS.md`; later administrative workflows, infrastructure deployment, and AI product capabilities remain future work.

## Repository layout

| Path | Intended ownership |
| --- | --- |
| `mobile/` | Flutter mobile application foundation |
| `backend/` | NestJS backend foundation |
| `admin/` | Next.js administrative web application foundation |
| `shared/` | Cross-project contracts, schemas, and tooling |
| `infrastructure/` | Deployment and infrastructure-as-code definitions |
| `ai/` | AI services, evaluation assets, and supporting tools |
| `docs/` | Architecture, workflow, and engineering documentation |

Uninitialized project directories contain a `.gitkeep` file so Git preserves the intended structure. Replace it when real files are introduced.

## Getting started

1. Install Git 2.28 or later.
2. Clone the repository.

### Running with Bun (Zero-Docker Workflow)

If you prefer to run the entire backend, proxy, and mobile app locally without Docker, you can use the Bun dev orchestrator:

```bash
bun dev
```

This single command will:
- Check and start your native PostgreSQL service.
- Start a Bun reverse proxy on port `8080` (with live CORS and request logging).
- Boot the NestJS backend in watch mode on port `3300`.
- Launch the Flutter web app at `http://localhost:51354` by default.
- Start the existing local Redis container automatically when Docker Desktop is running; otherwise the backend uses its local cache fallback.

*(See [docs/development/bun-dev-workflow.md](docs/development/bun-dev-workflow.md) for more details on proxy ports and backend-only execution).*

3. Activate the version-controlled hooks:

   ```bash
   git config core.hooksPath .githooks
   ```

4. Create a branch before making changes:

   ```bash
   git switch -c feat/short-description
   ```

5. Copy `.env.example` to an untracked `.env` only when local configuration is needed.

Application-specific prerequisites and commands are documented in each initialized application's README.

### Mobile foundation

Install the supported stable Flutter SDK, then run:

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=APP_ENV=development
```

See [`mobile/README.md`](mobile/README.md) for supported environments and platform prerequisites.

### Admin foundation

Install Node.js 20.9 or later, then run:

```bash
cd admin
npm install
npm run dev
```

See [`admin/README.md`](admin/README.md) for environment configuration and validation commands.

## Development rules

- Never commit directly to `main`; the pre-commit hook enforces this locally.
- Keep secrets out of Git. Commit placeholders only in `.env.example`.
- Use small pull requests with tests and documentation proportional to the change.
- Do not create dependencies between applications through internal file imports. Put stable shared contracts in `shared/`.
- Record material architecture decisions in `docs/architecture/decisions/`.

## Documentation

- [AI governance and evaluation architecture](docs/ai/governance-and-evaluation-architecture.md)

- [Backend setup and API notes](backend/README.md)
- [Local provider-document services](infrastructure/local/README.md)
- [Architecture](docs/architecture/README.md)
- [Branching strategy](docs/development/branching-strategy.md)
- [Git workflow](docs/development/git-workflow.md)
- [Project task tracker](PROJECT_TASKS.md)
- [Changelog](CHANGELOG.md)
- [AI agent rules](AGENTS.md)
- [Claude guidance](CLAUDE.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## Status

The platform has completed its tracked MVP scope: customer and provider booking journeys with realtime tracking, verification and trust workflows, payments (Razorpay behind a vendor-neutral gateway), governed advisory AI (issue classification and deterministic price estimates), push notifications, complaints and support operations, and the admin workspace including a trust-signal review queue. Remaining work — emergency dispatch policy, notification reminders for emergency slices, and post-MVP enhancements — is tracked in `PROJECT_TASKS.md`.

## License

No license has been selected. All rights are reserved until the repository owners add one.
