# ADR-0016: Adopt Razorpay as the Payment Provider

- Status: Accepted
- Date: 2026-08-25
- Owners: Arman2337

## Context

Payments were deferred from the original MVP scope (FN-097). The 2026-08-25 product decision reactivates the payments phase starting with FN-051: approve a provider and add an isolated, configured adapter with webhook trust controls. The market is India-first (INR pricing already published through FN-107's category pricing, money held in paise minor units), customers expect UPI, cards, and netbanking, and no payment provider had been approved before now. Razorpay was proposed by the user and approved on 2026-08-25.

Constraints from the security architecture: no live credentials in the repository, no storage of prohibited card data, idempotent order creation, webhook payloads are untrusted until signature-verified, and vendor coupling must stay behind an internal boundary.

## Decision

Adopt Razorpay as the first approved payment provider, isolated behind a vendor-neutral `PaymentGateway` interface inside `backend/src/payments/`, following the same boundary pattern as the push adapter (ADR-0015), the SMTP OTP adapter (ADR-0011), and the governed AI boundary (ADR-0014).

Boundaries:

- **No Razorpay SDK.** The adapter is a thin REST client over the official HTTPS Orders API using Node's global `fetch` with basic auth. This keeps the dependency surface at zero and the adapter replaceable.
- **Money is always integer paise** (`amountMinor`), INR only, mirroring FN-107. Floating-point money is prohibited at the boundary.
- **Webhook trust**: raw request bodies are verified as HMAC-SHA256 against `RAZORPAY_WEBHOOK_SECRET` with a timing-safe comparison before any parsing beyond byte capture. Checkout handshake signatures are verified as HMAC-SHA256 of `order_id|payment_id` against the key secret. Verification failures are rejected before any state changes.
- **Credentials are environment-only**: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` come from the environment and are never committed. `PAYMENT_PROVIDER=fake` provides a deterministic gateway for tests and local development and is prohibited in production, mirroring the AI/push governance rule. Test-mode keys are the only approved credentials until a production review.
- **No card or payment-credential data touches FixNow storage.** Card data lives entirely inside Razorpay Checkout. FixNow persists only gateway order identifiers, amounts, and verification outcomes (schema lands with FN-052).
- **Idempotency**: order creation carries a caller-supplied receipt/idempotency reference so retries cannot create duplicate orders; the booking-scoped idempotency conventions from FN-039 carry forward.

## Consequences

Positive: UPI, cards, and netbanking become available to Indian customers through one integration; the internal interface can gain later providers (Stripe, PayPal) without touching consumers; signature verification is testable offline against deterministic HMAC fixtures.

Costs: Razorpay becomes an operational dependency (KYC, settlement configuration, dispute tooling outside FixNow); webhook endpoint hardening becomes permanent review surface; test-mode keys must be provisioned by the owner for live verification.

Risks: credential leakage is mitigated by environment-only configuration; amount tampering is mitigated by verifying the gateway order amount against the internal order before acceptance (enforced in FN-052); replayed webhooks are mitigated by signature verification plus the delivery-record dedupe pattern proven in FN-062.

## Alternatives considered

- **Stripe** — rejected for this market phase: weaker UPI/netbanking ergonomics for India-first customers; remains a future adapter behind the same interface.
- **Cash-on-delivery / manual transfer** — rejected: no auditability, no dispute tooling, contradicts the trust architecture.
- **Razorpay SDK (`razorpay` npm package)** — rejected for now: the REST surface used is two endpoints; a hand-rolled client avoids a dependency upgrade treadmill. Revisit if the integration grows beyond orders, verification, and refunds.

## Validation

- `cd backend && npm run lint && npm test -- --runInBand && npm run build` — adapter, signature-verification, and configuration tests pass with deterministic HMAC fixtures and the fake gateway.
- Invalid signatures, tampered bodies, unsupported currencies, non-integer amounts, and misconfigured credentials are covered by focused tests.
- Live Razorpay verification (test-mode keys, one sandbox order) is recorded by the owner before FN-052 marks order persistence complete.
