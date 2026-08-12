# ADR-0012: Use Google Maps Platform for maps and navigation

- Status: Accepted
- Date: 2026-08-13
- Owners: FixNow product, privacy, security, and engineering

## Context

OD-010 permits precise provider tracking only for an accepted booking during the `On The Way` or equivalent active-travel state. Maps, navigation, and future ETA capabilities need an initial provider, while precise coordinates remain Restricted data with strict purpose, access, freshness, and deletion boundaries.

The integration must not make vendor responses authoritative for booking state or authorization. It must remain replaceable because pricing, coverage, platform terms, privacy obligations, and product needs may change.

## Decision

Use Google Maps Platform as FixNow's initial maps/navigation provider.

- Access Google services through a narrow application-owned adapter; domain and authorization logic do not import vendor-specific types.
- Send only the minimum location and route context required for the active-job purpose. Do not send unrelated profile, contact, booking-description, or stable internal identifiers when an opaque scoped reference suffices.
- FixNow authorizes tracking from authoritative booking, assignment, consent, permission, and account state before any vendor call or projection.
- Credentials are environment-specific, least-privileged, origin/application/API restricted, rotated, monitored, and never committed or logged.
- Disclose Google processing in the provider notice. Production enablement requires review of current terms, privacy/data-processing obligations, regional support, API selection, retention behavior, quota, cost limits, and operational ownership.
- Exclude vendor payloads, precise coordinates, and routes from unrestricted logs, analytics, crash reports, push notifications, and durable event metadata.
- Treat Google responses as untrusted input with schema, size, timeout, freshness, and plausibility validation. ETA remains an estimate with source/freshness and an unavailable state.
- This choice does not authorize raw route history. MVP retains only the latest point in approved ephemeral cache under OD-010.

## Consequences

Google Maps Platform provides a defined target for map display, navigation, and future ETA work. The adapter boundary limits vendor lock-in and keeps policy testable without network calls.

The project assumes vendor cost, quota, availability, terms, regional coverage, and privacy/subprocessor obligations. Production requires restricted credentials, billing alerts and ceilings, graceful provider-unavailable behavior, and periodic vendor review. Replacing the provider requires approval and an updated or superseding ADR.

## Alternatives considered

- Defer provider selection: rejected because OD-010 selects an initial provider and later tracking/ETA contracts need a stable boundary.
- Couple domain code directly to Google SDKs: rejected because it would mix authorization/business policy with vendor transport and make replacement difficult.
- Store raw routes for replay or analytics: rejected for the MVP because OD-010 prohibits historical precise GPS trails.

## Validation

- Contract-test the adapter with vendor-free fixtures and reject malformed, oversized, stale, or implausible responses.
- Test credential restrictions, configuration validation, timeouts, quota/rate limits, billing alerts, provider outage, and manual/unavailable fallback before production.
- Verify that unrelated users cannot obtain exact location and that logs, events, analytics, notifications, caches, and vendor requests contain only approved minimized data.
- Review current Google terms, privacy/data-processing behavior, regional coverage, API lifecycle, and cost before production and periodically thereafter.
