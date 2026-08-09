# ADR-0007: Adopt NestJS as the backend framework

- Status: Accepted
- Date: 2026-08-09
- Owners: Backend Team

## Context

FixNow requires a backend framework to serve the versioned JSON HTTP API (ADR-0001) and manage business logic around PostgreSQL (ADR-0002) and Redis (ADR-0003). The framework must provide a robust test harness, structured module boundaries, and type safety, in order to scale across the multiple domains (users, providers, bookings, payments, trust, etc.) without becoming a monolith.

## Decision

We will adopt NestJS as the primary framework for the backend application, using TypeScript and npm as the package manager.

## Consequences

- **Positive:** NestJS offers strong dependency injection, native support for decorators, easy testability (via Jest), and clear module structures which align nicely with FixNow's domain boundaries.
- **Costs:** It introduces learning curve overhead for developers not familiar with Angular-style architectures or RxJS concepts.
- **Risks:** Being highly opinionated, deviating from "the Nest way" could lead to friction in the future.
- **Operational effects:** Enables standardized bootstrapping, global exception filtering, and request validation pipelines across endpoints out of the box.

## Alternatives considered

- **Express/Koa:** While less opinionated and lightweight, they lack the structural opinions needed to build a highly scalable modular monolith, requiring us to reinvent dependency injection and architectural patterns.
- **Fastify:** Considered for raw speed, but its ecosystem is narrower compared to the batteries-included approach of NestJS, though NestJS can use Fastify under the hood if performance requires it.

## Validation

The decision is validated by scaffolding the application (`FN-017`) and proving that basic checks (linting, testing, and booting) work. Future backend feature tasks will prove whether the framework scales effectively with our domain structure.
