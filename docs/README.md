# FixNow documentation

The documentation is organized around stable engineering knowledge. Application-specific guides will be added when implementation begins.

## Product

- [Product requirements](product/requirements.md)
- [Domain glossary](product/glossary.md)

## Architecture

- [System architecture](architecture/README.md)
- [API conventions](architecture/api-conventions.md)
- [Error response conventions](architecture/error-response-conventions.md)
- [Event conventions](architecture/event-conventions.md)
- [Real-time and notification architecture](architecture/realtime-and-notification-architecture.md)
- [Data and storage architecture](architecture/data-architecture.md)
- [ADR template](architecture/decisions/0000-template.md)

## Security

- [Identity, roles, and permissions](security/identity-and-access.md)
- [Permission matrix](security/permission-matrix.md)
- [Security and privacy architecture](security/security-and-privacy-architecture.md)
- [Threat model and risk register](security/threat-model.md)

## Development

- [Branching strategy](development/branching-strategy.md)
- [Git workflow](development/git-workflow.md)

All documents must stay consistent with the repository structure and `README.md`. Record hard-to-reverse technical choices as Architecture Decision Records under `architecture/decisions/`.
