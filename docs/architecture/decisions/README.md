# Architecture Decision Records

Architecture Decision Records (ADRs) capture choices that are expensive to reverse or affect multiple components.

## Naming

Use four digits and a short kebab-case title:

```text
0001-select-primary-database.md
```

## Lifecycle

Use one status: `Proposed`, `Accepted`, `Deprecated`, or `Superseded by ADR-NNNN`. Never rewrite an accepted decision to hide history; create a new ADR and link both records.

Start with [`0000-template.md`](0000-template.md).
