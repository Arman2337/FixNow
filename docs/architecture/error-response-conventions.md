# Error response conventions

## Purpose

FixNow APIs use a single safe, machine-readable error shape based on Problem Details for HTTP APIs. The format follows the semantics of RFC 9457 and adds namespaced application fields. These examples define contracts; no endpoint is implemented by this document.

Error responses MUST use:

```http
Content-Type: application/problem+json
```

## Problem shape

```json
{
  "type": "https://api.fixnow.example/problems/validation-failed",
  "title": "Request validation failed",
  "status": 422,
  "code": "validation-failed",
  "detail": "One or more fields require correction.",
  "instance": "/api/v1/service-requests/request-instance-opaque",
  "correlationId": "2d41c4d8-46aa-4dd4-9e89-9bd0a06cb83e",
  "errors": [
    {
      "path": "location.latitude",
      "code": "out-of-range",
      "message": "Must be between -90 and 90."
    }
  ]
}
```

### Required members

| Member | Rule |
| --- | --- |
| `type` | Stable HTTPS URI identifying the problem class. It MUST be documentation-addressable before a public release. |
| `title` | Short, stable human summary of the problem class. It MUST NOT contain request-specific or sensitive data. |
| `status` | HTTP status code repeated as a number and equal to the actual response status. |
| `code` | Stable lowercase kebab-case application code used for programmatic handling. |
| `correlationId` | Opaque diagnostic identifier equal to the `X-Correlation-ID` response header. |

### Optional members

| Member | Rule |
| --- | --- |
| `detail` | Safe explanation specific to this occurrence. It MUST NOT reveal internals, secrets, existence-protected resources, or unnecessary personal data. |
| `instance` | Opaque URI reference for this occurrence. It MUST NOT expose a database key, token, filesystem path, stack frame, or sensitive query string. |
| `errors` | Bounded validation issue array, allowed only when field-level correction is safe and useful. |
| `retryAfterSeconds` | Non-negative integer hint consistent with the `Retry-After` header; clients treat it as a hint, not a guarantee. |

- Extension names MUST be documented before use.
- A problem response MUST contain only one top-level problem. Multiple validation issues belong in the bounded `errors` array.
- Clients MUST primarily branch on HTTP status and stable `code`; they MUST NOT parse `title`, `detail`, or `message` text.
- Human-readable text is not a localization contract. User-facing clients SHOULD map stable codes to reviewed localized copy and MAY use safe server detail as supporting diagnostic text.

## Validation issues

Each `errors` item uses:

```json
{
  "path": "profile.displayName",
  "code": "too-long",
  "message": "Must contain at most 100 characters."
}
```

- `path` MUST use a documented dotted field path or a safe request section such as `body`, `query.limit`, or `headers.idempotencyKey`.
- Array positions MAY use bracket notation, for example `items[0].quantity`, only when revealing the position is safe.
- `code` MUST be stable, lowercase kebab-case, and more specific than the top-level problem code.
- `message` MUST be safe, concise, and actionable. It MUST NOT echo the rejected value by default.
- The array MUST have a documented maximum. If more issues exist, the response SHOULD include the most actionable deterministic subset.
- Validation issue ordering MUST be deterministic to support testing and accessible presentation.

## Standard problem catalogue

Endpoint specifications may define narrower codes, but they MUST preserve these semantics.

| HTTP status | Default code | Meaning | Retry default |
| --- | --- | --- | --- |
| `400` | `malformed-request` | JSON, path, query, or protocol syntax could not be parsed | No; correct request |
| `401` | `authentication-required` | Authentication is missing, invalid, or expired | Re-authenticate; do not loop |
| `403` | `forbidden` | Authenticated caller lacks permission | No |
| `404` | `resource-not-found` | Resource/route is absent or intentionally existence-protected | No |
| `405` | `method-not-allowed` | Resource exists but method is unsupported | No |
| `406` | `not-acceptable` | Requested response representation is unsupported | No |
| `408` | `request-timeout` | Server did not receive/complete the request in its allowed time | Safe/idempotent only |
| `409` | `conflict` | Current state conflicts with the requested operation | Reconcile first |
| `409` | `idempotency-key-reused` | Key was previously used with a different effective request | No; use a new key for a new operation |
| `410` | `resource-gone` | Resource intentionally no longer exists and that fact may be disclosed | No |
| `412` | `precondition-failed` | Supplied resource version is stale | Re-read then decide |
| `413` | `payload-too-large` | Request exceeds the endpoint's size limit | No; reduce request |
| `415` | `unsupported-media-type` | Request representation is unsupported | No; correct media type |
| `422` | `validation-failed` | Parsed input violates the request schema | No; correct fields |
| `422` | `domain-rule-violated` | Request is well-formed but violates a disclosed domain rule | No until state/input changes |
| `425` | `request-too-early` | Server cannot safely process a potentially replayed request yet | Later, only if replay-safe |
| `428` | `precondition-required` | Required concurrency precondition is missing | Add current precondition |
| `429` | `rate-limit-exceeded` | Caller exceeded an applicable limit | Respect `Retry-After` |
| `500` | `internal-error` | Unexpected server failure | Only if documented and safe |
| `502` | `upstream-invalid-response` | Required upstream returned an invalid response | Safe/idempotent with backoff |
| `503` | `service-unavailable` | Capability is temporarily unavailable or not ready | Respect `Retry-After` where present |
| `504` | `upstream-timeout` | Required upstream exceeded its deadline | Safe/idempotent with backoff |

### Choosing status and code

- Authentication failure is `401`; authenticated lack of permission is normally `403`.
- Use `404` instead of `403` when disclosing existence would violate policy.
- Use `409` for conflicts with current resource or idempotency state.
- Use `412` for a supplied conditional request that is stale and `428` when a required condition was omitted.
- Use `422 validation-failed` for request-schema violations and `422 domain-rule-violated` only for safely disclosable business preconditions.
- A dependency failure MUST NOT automatically become `500`; use `502`, `503`, or `504` when that distinction is safe and operationally accurate.
- A public response MUST NOT reveal whether a protected dependency, database, queue, cache, or vendor caused an internal failure unless the contract intentionally exposes that distinction.

## Security and privacy

Problem responses MUST NOT contain:

- Stack traces, exception class names, source paths, SQL, queries, infrastructure names, internal hostnames, or vendor secrets.
- Authentication tokens, OTPs, cookies, signatures, private object URLs, idempotency request bodies, or credential hints.
- Full rejected payloads, KYC data, precise location, financial-provider payloads, complaint evidence, or AI prompts/model output.
- Resource-existence details that bypass authorization or enable identity/account enumeration.
- Raw dependency messages that have not been mapped to a reviewed application problem.

Server logs MAY record controlled internal diagnostics linked by correlation ID, but must follow redaction, access, and retention policy. Public details and internal diagnostics are separate representations.

## Expected and unexpected failures

- Expected validation, domain, authentication, authorization, concurrency, and integration outcomes MUST be mapped explicitly to stable problems.
- An unexpected exception MUST be caught at the API boundary and returned as `500 internal-error` with generic safe detail.
- The original exception MUST NOT be serialized into the response.
- Unexpected failures SHOULD produce structured internal telemetry with the correlation ID and an approved error classification.
- The system MUST avoid duplicate error reporting when the same failure crosses middleware, controller, domain, and integration boundaries.

Generic unexpected response:

```json
{
  "type": "https://api.fixnow.example/problems/internal-error",
  "title": "The request could not be completed",
  "status": 500,
  "code": "internal-error",
  "detail": "Try again later or contact support with the correlation ID.",
  "correlationId": "2d41c4d8-46aa-4dd4-9e89-9bd0a06cb83e"
}
```

## Compatibility

- A problem `type` and `code` MUST never be reused for a different semantic condition.
- Adding an optional problem member is compatible; clients MUST ignore unknown members.
- Removing or renaming a member, changing its type or meaning, or making an optional member required is breaking.
- Changing the HTTP status for an existing code is breaking unless a reviewed migration proves all supported clients handle both.
- Adding a narrower code may be compatible only when clients already handle the HTTP status and documented broader category generically.
- Human text MAY improve without a major version change and MUST NOT be used as a machine contract.

## Testing requirements

Each implemented endpoint MUST test:

- The expected status, media type, stable code, and correlation header/body equality.
- Safe field-level validation details and deterministic ordering where applicable.
- Authentication, authorization, ownership, and existence-protection behavior.
- Conflict, stale concurrency, idempotency misuse, and rate-limit behavior when applicable.
- Unexpected exception mapping without leaked internals or sensitive values.
- Retry headers and hints where the endpoint advertises transient recovery.
- Contract compatibility for supported client versions.
