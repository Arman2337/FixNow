# ADR-0015: Adopt Firebase Cloud Messaging for Push Notification Delivery

- Status: Accepted
- Date: 2026-08-24
- Owners: Arman2337

## Context

Providers currently learn about incoming jobs only by polling the eligible-request feed while the app is open, and customers must open the app to see booking progress. The realtime WebSocket gateway already delivers authoritative projections, but only during a live connection. FN-061 requires device registration and privacy-safe push delivery through an approved provider. Firebase Cloud Messaging (FCM) was proposed as the candidate; the user approved FCM adoption on 2026-08-24.

Constraints from the security architecture: no sensitive detail on lock screens, no push delivery as the sole source of truth, tokens are personal data requiring lifecycle control, and vendor coupling must stay behind an internal boundary.

## Decision

Adopt FCM as the first approved push transport, isolated behind a vendor-neutral `PushDelivery` interface inside `backend/src/notifications/push/`, following the same boundary pattern as the SMTP OTP adapter (ADR-0011) and the governed AI boundary (ADR-0014).

Boundaries:

- The backend owns all device-token lifecycle: registration, reassignment on account change, revocation, and deletion. Tokens are stored server-side only; clients never read them back.
- Delivery payloads carry no sensitive content: booking identifiers, event kinds, and generic titles only. Lock-screen-visible bodies stay non-personal until a redaction review approves more.
- Push is never the sole source of truth. Domain state remains authoritative in PostgreSQL with the existing WebSocket projections and HTTP reconciliation as recovery paths.
- The `fake` provider exists for deterministic tests and local development and is prohibited in production, mirroring the AI governance rule. Live FCM delivery activates only when `PUSH_PROVIDER=fcm` plus a service-account credential file are configured.
- Mobile integration is compile-time gated (`PUSH_NOTIFICATIONS_ENABLED`) so builds without Firebase configuration remain valid and honestly show notifications as unavailable.

## Consequences

Positive: providers receive job alerts with the app closed; customers see booking progress without opening the app; one internal interface can gain additional transports (e.g. WhatsApp) later without touching consumers.

Costs: a Google/Firebase project becomes an operational dependency; `firebase-admin` adds a substantial dependency to the backend; token hygiene (stale/unregistered tokens) becomes ongoing operational work.

Risks: credential leakage is mitigated by loading the service-account JSON from an untracked local path referenced by `FCM_CREDENTIALS_FILE`; vendor lock-in is bounded to the single adapter class; abuse is bounded by throttled registration endpoints and bounded token lengths.

## Alternatives considered

- **Polling-only feed (status quo)** — rejected: misses jobs whenever the provider closes the app.
- **Third-party notification aggregation services** — rejected for now: another hosted dependency without an approved ADR and cost profile.
- **Raw APNs/FCM HTTP integrations per platform** — rejected: duplicated platform-specific work that firebase-admin already encapsulates.

## Validation

Unit tests cover registration/reassignment/revocation authorization, token bounds, configuration gating, and fake-provider delivery. Live delivery is validated manually against a configured development device once credentials exist; evidence recorded in the FN-061 completion notes. Reconsider this decision if FCM policy changes make delivery unusable in target markets or costs become material.

## Related

- FN-061 (implementation), FN-062 (domain notifications, emergency portion still gated by FN-063)
- ADR-0011 (email OTP adapter boundary precedent), ADR-0014 (governed external-provider pattern)
