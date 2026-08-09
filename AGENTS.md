# AI Agent Development Rules

These rules apply to every AI agent working anywhere in this repository. More specific `AGENTS.md` files may add constraints for a subtree, but they must not weaken these rules.

## Mission and current phase

FixNow is a polyglot monorepo planned around `mobile`, `backend`, `admin`, `shared`, `infrastructure`, and `ai` domains. The repository is currently foundation-only. Do not scaffold Flutter, NestJS, Next.js, cloud resources, databases, or AI services unless the user explicitly requests that work.

## Instruction precedence

1. Follow system and platform safety constraints.
2. Follow the user's current request.
3. Follow this file and any more specific subtree instructions.
4. Follow established repository conventions and documentation.
5. When instructions conflict or a destructive action is unclear, stop and ask.

## Required working method

1. Read `README.md`, `PROJECT_TASKS.md`, relevant files under `docs/`, and the nearest `AGENTS.md` before editing.
2. Inspect the working tree with `git status --short` and preserve unrelated user changes.
3. State assumptions when requirements are ambiguous and the assumption affects architecture, security, data, cost, or external behavior.
4. Make the smallest cohesive change that fully solves the request. Do not perform unrelated refactors.
5. Add or update tests and documentation when behavior changes.
6. Run the narrowest relevant checks first, then broader checks where risk warrants them.
7. Review the final diff for correctness, secrets, generated files, and unintended edits.
8. Report what changed, what was verified, and any remaining risk.

## Project Task Execution Protocol

`PROJECT_TASKS.md` is the authoritative, permanent record of project work. Every AI coding agent MUST read both `AGENTS.md` and `PROJECT_TASKS.md` before beginning implementation.

Before starting a tracked task, an agent must:

1. Read `PROJECT_TASKS.md` in full.
2. Check the task's explicit dependencies and confirm each is `✅ Completed`.
3. Find an eligible `⬜ Pending` task, or use the task explicitly assigned by the user.
4. Confirm that no `In Progress` task conflicts with its files or areas.
5. Change the selected task's status to `In Progress` and add it under **Current Work**.
6. Create or use the branch specified by the task, following the branching strategy.
7. Work only on that task.

Unless the user explicitly instructs otherwise:

```text
ONE AGENT RUN = ONE TASK
```

Complete exactly one tracked task, run its required validation, update its status and completion record, remove it from **Current Work**, update the progress summary, and stop. Do not independently start related or future tasks.

When asked to "Take the next task," select the first task satisfying all of these conditions:

```text
Status = ⬜ Pending
AND all Depends On tasks = ✅ Completed
AND the task is not otherwise blocked
```

Choose by priority (`P0`, then `P1`, `P2`, and `P3`). Within one priority, generally choose the lowest eligible task ID unless dependencies make another ordering necessary.

If work cannot continue, do not claim completion. Change the status from `In Progress` to `Blocked` and add `### Blocker` and `### Required To Unblock` sections with the exact missing decision, dependency, credential, service, or prerequisite. Do not silently skip blockers.

A task becomes `✅ Completed` only after every acceptance criterion and required validation succeeds. If validation cannot run or fails, the task is not complete; record the limitation truthfully. Fill in `Completed By`, `Completed Date`, `Commit`, and `PR`, using `Pending` when a commit or PR does not yet exist. Never invent identifiers.

Keep completed and cancelled tasks as permanent history. Never reuse a task ID. If implementation reveals additional work, add a new `⬜ Pending` task with the next unused ID and continue only the assigned task. Split work that is too large for one focused agent run. Before editing shared files, compare the task's **Files / Areas** with active tasks and avoid significant concurrent overlap unless explicitly coordinated.

### Agent command examples

```text
Read AGENTS.md and PROJECT_TASKS.md.
Take the next eligible task.
Complete exactly one task.
Run all required validation.
Update PROJECT_TASKS.md.
Do not start another task.
```

```text
Read AGENTS.md and PROJECT_TASKS.md.
Work only on FN-025.
Check its dependencies first.
Complete it, validate it, and update its completion record.
Do not work on any other task.
```

```text
Read PROJECT_TASKS.md and tell me:
- current progress
- active tasks
- blocked tasks
- next 5 eligible tasks

Do not modify code.
```

## Repository boundaries

- `mobile/`: mobile product code only.
- `backend/`: server-side APIs, jobs, and domain services.
- `admin/`: administrative web experience.
- `shared/`: versionable contracts, schemas, generated clients, and truly cross-project utilities. Do not turn it into a miscellaneous dumping ground.
- `infrastructure/`: infrastructure as code, deployment configuration, and operational assets.
- `ai/`: model-facing services, prompts, evaluations, and AI-specific tooling.
- `docs/`: durable project knowledge, architecture decisions, runbooks, and workflows.

Applications must not import another application's private source files. Cross-boundary communication must use documented APIs, events, or packages owned by `shared/`.

## Architecture rules

- Prefer explicit module boundaries and dependency direction over convenience imports.
- Keep domain logic independent of transport, UI, persistence, and vendor SDKs where practical.
- Treat API schemas, events, and shared types as contracts. Version breaking changes deliberately.
- Keep configuration externalized. Validate required configuration at process startup.
- Add an Architecture Decision Record (ADR) for hard-to-reverse choices such as databases, cloud vendors, authentication, public contracts, or new cross-cutting frameworks.
- Do not introduce a new language, framework, runtime, database, queue, or hosted dependency without explicit approval and documented rationale.

## Security and privacy

- Never commit secrets, tokens, private keys, production identifiers, customer data, or real credentials.
- Use obvious placeholders in `.env.example`; keep real `.env` files untracked.
- Apply least privilege to credentials, network access, and cloud roles.
- Validate untrusted input at trust boundaries and encode output for its destination.
- Do not log secrets, authentication material, sensitive personal data, or full third-party payloads.
- Use parameterized database access and vetted cryptographic libraries.
- Flag authentication, authorization, payments, personal data, destructive migrations, and public network exposure for focused review.
- Follow `SECURITY.md` for vulnerability handling. Do not disclose vulnerabilities in public issues.

## Quality standards

- Prefer readable, typed, deterministic code with clear error handling.
- Avoid hidden side effects, global mutable state, duplicated business rules, and premature abstraction.
- Preserve backward compatibility unless a breaking change is approved and documented.
- Tests must cover the changed behavior, important errors, permissions, and boundary conditions.
- Do not disable lint, type, security, or test rules merely to make checks pass. Document any narrowly scoped exception.
- Do not hand-edit generated files. Update their source or generator and regenerate them.

## Dependencies and generated assets

- Use the package manager selected by each project once its manifest exists; do not mix lockfile ecosystems.
- Pin toolchains and commit lockfiles where the ecosystem expects them.
- Prefer maintained dependencies with compatible licenses and a clear need.
- Do not download or execute unknown scripts without reviewing their source and obtaining required approval.
- Keep binaries, build output, caches, reports, and local state out of Git unless explicitly designated as source artifacts.

## Git and pull requests

- Never commit directly on `main`. Create branches following `docs/development/branching-strategy.md`.
- Use Conventional Commit messages: `type(scope): imperative summary`. The scope is optional.
- Do not rewrite shared history, force-push, delete branches, or discard user changes without explicit permission.
- Stage files intentionally. Before committing, inspect `git diff --cached`.
- Pull requests must explain why, summarize the change, describe verification, and identify risk or rollout needs.
- Keep commits reviewable and free of secrets, debug output, unrelated formatting, and generated noise.

## Documentation rules

- All UI implementation tasks must read and follow `DESIGN.md` before modifying UI.
- Update `README.md` when setup, top-level structure, or primary workflows change.
- Update architecture docs when component boundaries or data flows change.
- Add ADRs under `docs/architecture/decisions/` using the template for material decisions.
- Write commands that can be copied safely and specify prerequisites and verification.
- Use repository-relative Markdown links and verify that linked files exist.

## Tool and command safety

- Prefer read-only inspection before mutation.
- Never run recursive deletion, hard resets, force pushes, production deployments, database drops, or irreversible migrations without explicit user authorization and exact target verification.
- Do not bypass hooks with `--no-verify` unless the user explicitly authorizes it for a documented exceptional reason.
- Do not use network access, modify external systems, publish packages, open pull requests, or send messages unless the task authorizes it.
- Avoid commands that expose environment variables or credentials in logs.

## Definition of done

Work is complete only when the requested outcome exists, relevant checks pass, documentation is synchronized, the diff contains no unrelated changes or secrets, and the final report states any limitation. If a check cannot run, say exactly which check and why.
