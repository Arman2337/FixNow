# ADR-0013: Adopt Next.js for the admin application

- Status: Accepted
- Date: 2026-08-14
- Owners: FixNow engineering

## Context

FixNow needs an accessible, typed administrative web application foundation. The admin surface will eventually contain authenticated operational workflows, but FN-046 is limited to the application shell, environment validation, and development quality gates. The repository already uses Node.js and TypeScript for the backend, so sharing that toolchain reduces operational and contributor overhead.

## Decision

Use Next.js with the App Router and TypeScript for the FixNow admin application. Use React Server Components by default, add client components only when interaction requires them, and keep admin code isolated under `admin/`. Use ESLint with the Next.js Core Web Vitals and TypeScript rules. Consume validated configuration through a dedicated module rather than reading environment variables throughout the application.

The application will implement FixNow's existing semantic design tokens in CSS. This decision does not approve an authentication scheme, deployment vendor, hosted dependency, admin workflow, or cross-application private-source import.

## Consequences

- The admin application gains file-based routing, server rendering, TypeScript integration, and established accessibility and performance guidance.
- Contributors must maintain the Node.js/React dependency chain and monitor framework security updates.
- Framework upgrades can affect rendering and caching behavior and therefore require normal validation.
- Shared contracts must remain versioned under `shared/`; the admin application cannot import backend-private source.

## Alternatives considered

- Vite with React offers a smaller client-only foundation, but would require independently selecting routing, server-rendering, and related conventions as admin needs grow.
- A framework-free application minimizes dependencies but creates avoidable routing, rendering, bundling, and testing decisions.
- Other React meta-frameworks are viable but do not offer a demonstrated repository-specific advantage over Next.js.

## Validation

Validate the decision through a production build, strict type checking, ESLint, automated shell tests, accessible semantic structure, and environment-validation tests. Reconsider if operational constraints, security maintenance, or measured performance make the framework unsuitable.
