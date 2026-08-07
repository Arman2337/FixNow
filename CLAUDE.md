# Claude Project Guidance

Read and follow [`AGENTS.md`](AGENTS.md) as the authoritative repository-wide agent policy. This file adds Claude-specific operating guidance without replacing those rules.

## Start every task

1. Read `AGENTS.md` and the documentation relevant to the requested area.
2. Run `git status --short --branch` and preserve unrelated changes.
3. Confirm the task's scope. The current repository phase is foundation-only until explicitly changed.
4. Search before editing; do not assume a component or convention exists.

## Working conventions

- Keep changes narrow, reviewable, and consistent with the documented boundaries.
- Prefer direct evidence from repository files over assumptions.
- Do not scaffold an application, choose a vendor, or introduce a dependency unless explicitly requested.
- Use version-controlled hooks from `.githooks` and never bypass them casually.
- Validate the final diff, run relevant checks, and report exact verification results.
- If a request would expose secrets, destroy data, rewrite shared history, or affect an external system, pause for explicit authorization.

## Repository map

- `mobile/`: future Flutter client
- `backend/`: future NestJS services
- `admin/`: future Next.js application
- `shared/`: future cross-project contracts and packages
- `infrastructure/`: future infrastructure and deployment definitions
- `ai/`: future AI services, prompts, and evaluations
- `docs/`: durable engineering documentation

## Skill routing

When an available skill directly matches the user's request, read and follow it. In particular, use documentation skills for substantial documentation work, investigation skills for debugging, review skills for code review, and shipping skills only when the user asks to ship or open a pull request.

## Completion checklist

- Requested scope is complete and nothing unrelated changed.
- Relevant checks passed, or the limitation is explicit.
- Documentation and examples match the implementation.
- No secrets, credentials, local paths, or generated noise are staged.
- Git state and next steps are clear in the final response.
