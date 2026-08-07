# GitHub Copilot Instructions

Follow the repository-wide rules in `/AGENTS.md` and the architecture under `/docs/architecture/`.

- This repository is foundation-only. Do not generate Flutter, NestJS, Next.js, infrastructure, or AI application code unless explicitly requested.
- Respect directory boundaries. Never import private application source across `mobile`, `backend`, `admin`, or `ai`; use stable contracts in `shared`.
- Prefer typed, readable code with explicit errors, input validation, and tests for changed behavior.
- Never suggest or insert real secrets, credentials, personal data, insecure cryptography, unparameterized SQL, or authorization bypasses.
- Keep configuration in environment variables and document placeholders in `.env.example`.
- Use Conventional Commits and branch naming from `docs/development/branching-strategy.md`.
- Update documentation for setup, contracts, architecture, or workflow changes.
- Do not invent APIs, packages, commands, or conventions. Inspect the repository first.
- Avoid unrelated refactors and generated noise. Keep suggestions small enough to review.
