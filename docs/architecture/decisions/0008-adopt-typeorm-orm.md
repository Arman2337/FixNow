# ADR-0008: Adopt TypeORM as the primary ORM for PostgreSQL

- Status: Accepted
- Date: 2026-08-09
- Owners: FixNow engineering

## Context
ADR-0002 established PostgreSQL as our authoritative system of record. To interact with the database safely, manage migrations, and adhere to our domain-driven design, we need an Object-Relational Mapper (ORM) or a robust query builder. The selected tool must support NestJS natively, handle database schema migrations intuitively, provide strong TypeScript safety, and support advanced transactional behaviors necessary for our booking and identity workflows.

## Decision
Use TypeORM as the primary ORM for all PostgreSQL interactions.

- We will utilize `@nestjs/typeorm` to integrate TypeORM cleanly into our backend architecture.
- Domain modules will declare their own entity boundaries via decorators.
- TypeORM CLI will manage and generate database schema migrations.
- We will prefer the Data Mapper pattern (using Repositories injected via NestJS) over Active Record to keep our entities clean.

## Consequences

### Positive
- Strong TypeScript integration via decorators.
- First-class support within the NestJS ecosystem.
- Robust transaction handling and connection pooling abstraction.
- Automatic migration generation based on entity metadata.

### Costs and risks
- Potential performance issues with overly complex entity relationship cascades if not carefully reviewed.
- Heavy reliance on decorators, making entities slightly coupled to the ORM logic.

## Validation
- Ensure TypeORM module connects to PostgreSQL during the foundation phase validation.
- Verify migrations up/down functionality successfully mutates and rolls back the database state.
