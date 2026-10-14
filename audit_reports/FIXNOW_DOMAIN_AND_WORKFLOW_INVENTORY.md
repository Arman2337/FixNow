# FixNow — Domain Models, Workflows & Business Rules Inventory

**Audit Date:** 2026-10-13  
**Audit Scope:** Repository-Wide Domain Logic, State Machines, Invariants, and Business Policies  
**Source Code Baseline:** `shared/`, `backend/src/`, `mobile/lib/`  

---

## 1. Domain Terminology & System Axioms

To prevent architectural ambiguity, FixNow enforces strict domain vocabulary across backend services, mobile clients, and administrative dashboards:

| Term | Formal Definition & Invariant Boundary | Anti-Pattern / What It Is NOT |
|---|---|---|
| **Service Request** | An ephemeral customer expression of intent containing category, requested items, location coordinates, and preferred time window. Precedes provider assignment. | It is NOT a binding contract or active job until a provider claims it. |
| **Booking** | The single authoritative lifecycle entity representing the contract between customer, assigned provider, and platform. Created at submission; transitions through verified checkpoints. | It is NOT merely a calendar entry; it binds financial liabilities and guarantees. |
| **Job** | Informal provider-facing terminology used in mobile screens (`ProviderJobsScreen`, `ProviderActiveJobCockpitScreen`). Always maps directly to an underlying `Booking` record. | Never used as an authoritative database entity name. |
| **Verified** | A provider who has successfully passed identity verification, background check, trade license scrutiny, and has been approved by staff. | Distinct from being "available" or "online". |
| **Eligible** | A verified provider whose skills match the booking category, whose declared service radius covers the customer coordinates, and who has capacity. | Distinct from having accepted the request. |
| **Available / Online** | A provider who has declared operational readiness via the status toggle (`AVAILABLE`) and whose weekly schedule allows dispatches. | A provider can be verified and eligible, yet offline/unavailable. |
| **Matched / Assigned** | A booking that has been atomically claimed by an eligible provider. Provider identity is bound; concurrency locks released. | Provider has not yet started journey (`EN_ROUTE`). |
| **Advisory AI** | AI models (Gemini Vision, Speech-to-Text, Embeddings) provide non-binding recommendations only (ADR-0014). Never sets binding prices or overrides business state. | AI output is NEVER an authoritative lifecycle transition. |
| **Notification** | An asynchronous communication side-effect (Push FCM, SMS, In-App). | A notification NEVER determines authoritative domain state. |

---

## 2. Identity, Account Lifecycle & Authorization State Machine

### 2.1 User Roles & Account States
The platform defines 11 distinct role codes and 4 authoritative account statuses:
- **Roles:** `customer`, `provider_applicant`, `verified_provider`, `provider_reviewer`, `support_agent`, `trust_safety_reviewer`, `finance_operator`, `service_catalog_manager`, `operations_administrator`, `security_administrator`, `auditor`.
- **Account Statuses:** `pending_verification`, `active`, `suspended`, `banned`.

```
[Registration] ──► pending_verification
                         │ (Valid 6-Digit Email OTP)
                         ▼
                       active ◄────────────────┐
                         │                     │ (Admin Reinstatement)
                         ├──────► suspended ───┘
                         │
                         ▼
                       banned (Terminal)
```

### 2.2 Token Lifecycle & Replay Revocation
- **Access Tokens:** Short-lived JWTs (15 minutes). Carries `userId`, `roles`, and base64-encoded `accountStatus`.
- **Refresh Tokens:** Long-lived cryptographically random 64-character tokens (30 days) stored in `auth_sessions`.
- **Rotation & Replay Detection:**
  - Upon calling `POST /auth/token/refresh`, the presented refresh token is immediately invalidated and replaced with a newly generated token within the same token family.
  - If an invalidated refresh token is ever presented again (indicating token theft or replay attack), the backend revokes the **entire token family**, immediately terminating all active sessions for that user across all devices (`auth/token-lifecycle.service.ts:80-94`).

---

## 3. Service Catalog & Dynamic Pricing Rules

### 3.1 Sub-Service Item Selection & Server-Side Pricing
- Customers select itemized tasks (e.g., "Tap & Mixer Repair", "Switchboard Replacement") and specify integer quantities (>= 1).
- **Security Rule:** Clients submit only `subServiceId` and `quantity`. Clients are **strictly forbidden from submitting unit prices**.
- When `POST /bookings` executes, the backend re-reads each `sub_service` from PostgreSQL **inside the database transaction**, ensuring prices cannot be tampered with or become stale during checkout.
- If any sub-service is inactive, belongs to a different category, or lacks an active INR price, the entire transaction rolls back with `400 Bad Request`.

### 3.2 Statutory Goods & Services Tax (GST) Calculation
All financial calculations operate in integer minor units (paise) to prevent floating-point rounding errors:
```
subtotalMinor = ∑ (subService.unitPriceMinor × quantity)
gstMinor      = round(subtotalMinor × 0.18)
totalMinor    = subtotalMinor + gstMinor
```
*GST is fixed at statutory 18% in accordance with Indian tax regulations.*

### 3.3 "Price on Request" Honest Abstention
If an administrator configures a service category without a fixed baseline price (`price_amount = NULL`), the platform engages honest abstention:
- The UI displays "Quote on Inspection" or "Price on Request".
- The checkout sheet does not force an upfront estimate.
- Initial booking total is set to 0, and the provider submits an on-site itemized assessment after diagnosis.

---

## 4. Authoritative Booking Lifecycle State Machine

The core business entity `Booking` enforces a strict, non-cyclical state machine (`shared/booking-lifecycle.types.ts:10-25`):

```
                        ┌──────────────────┐
                        │    REQUESTED     │
                        └────────┬─────────┘
                                 │
                   (Atomic Provider Claim)
                                 ▼
                        ┌──────────────────┐
                        │     ASSIGNED     │
                        └────────┬─────────┘
                                 │
                     (Provider Departs)
                                 ▼
                        ┌──────────────────┐
                        │     EN_ROUTE     │
                        └────────┬─────────┘
                                 │
                   (HMAC 4-Digit OTP Verified)
                                 ▼
                        ┌──────────────────┐
                        │   IN_PROGRESS    │
                        └────────┬─────────┘
                                 │
                  (Service Completed & Verified)
                                 ▼
                        ┌──────────────────┐
                        │    COMPLETED     │ (Terminal)
                        └──────────────────┘
```

*Note: `CANCELLED` is reachable from `REQUESTED`, `ASSIGNED`, `EN_ROUTE`, and `IN_PROGRESS` under specific role-based policies. Both `COMPLETED` and `CANCELLED` are terminal states.*

### 4.1 Allowed vs. Rejected Transitions

| From State | Allowed Target State | Triggering Actor | Invariant Constraints & Business Rules |
|---|---|---|---|
| `REQUESTED` | `ASSIGNED` | Eligible Provider | Provider must be verified, online, skilled in category, and within service radius. Atomic CAS lock. |
| `REQUESTED` | `CANCELLED` | Customer or Sweeper | Customer can cancel freely. Background sweeper cancels after 300s timeout if no provider claims. |
| `ASSIGNED` | `EN_ROUTE` | Assigned Provider | Provider taps "Start Journey". Customer receives arrival notification; provider GPS coordinates become unredacted. |
| `ASSIGNED` | `CANCELLED` | Customer or Provider | If cancelled by customer after provider is assigned, may incur cancellation fee. If cancelled by provider, booking returns to dispatch pool. |
| `EN_ROUTE` | `IN_PROGRESS` | Assigned Provider | **Strict Security Invariant:** Can ONLY be triggered by providing a valid 4-digit Service-Start OTP derived from customer's booking salt. |
| `EN_ROUTE` | `CANCELLED` | Provider or Admin | Provider must provide abandonment reason (`UNSAFE_CONDITIONS`, `CUSTOMER_UNAVAILABLE`, etc.). |
| `IN_PROGRESS` | `COMPLETED` | Assigned Provider | Work finished; line-item adjustments locked; triggers payment collection and 30-day warranty window. |
| `IN_PROGRESS` | `CANCELLED` | Provider or Admin | Only permitted under formal abandonment reasons (`JOB_MISDESCRIBED`, `RESOURCES_UNAVAILABLE`). Opens support dispute. |
| `COMPLETED` | Any | None | **Forbidden.** Terminal state. No transitions allowed. |
| `CANCELLED` | Any | None | **Forbidden.** Terminal state. No transitions allowed. |

### 4.2 Two Providers Claiming Simultaneously (Race Condition Protection)
When two eligible technicians attempt to accept the same booking at the exact same millisecond:
1. Both requests enter `BookingsController.acceptBooking()`.
2. The method initiates a database transaction with `pessimistic_write` row locking on the `bookings` record.
3. The first technician acquires the lock and executes:
   ```sql
   UPDATE bookings 
   SET provider_id = :providerId, status = 'ASSIGNED', version = version + 1 
   WHERE id = :bookingId AND status = 'REQUESTED';
   ```
4. Exactly 1 row is affected. The lock is released, and the transaction commits.
5. The second technician acquires the row lock. The `WHERE status = 'REQUESTED'` predicate fails because the status is now `ASSIGNED`.
6. Zero rows are affected. The backend raises a `409 ConflictException` (`"Booking has already been accepted by another provider"`).
7. If the same provider retries their own request, the endpoint returns `200 OK` idempotently without creating duplicate events.

### 4.3 Service Start Verification Handshake (HMAC OTP)
To eliminate fraud where dishonest technicians claim to have started work without physically arriving at the customer's residence:
- **Generation:** Customer opens `BookingTrackingScreen`. The backend computes a deterministic 4-digit PIN via `HMAC-SHA256(serverSecret, bookingId + customerId)` modulo 10000.
- **Display:** The customer sees the 4-digit code on their smartphone screen with explicit instructions: *"Share this code only when technician is physically present at your doorstep."*
- **Verification:** The technician enters the code into `FixOtpInputSheet`.
- **Validation:** The backend executes `crypto.timingSafeEqual` over the computed and submitted HMAC digests to prevent timing attacks. Only on exact match does status transition to `IN_PROGRESS`.

### 4.4 Provider Abandonment Codes
To prevent providers from falsely marking uncompleted work as "COMPLETED", the system provides formal abandonment codes when cancelling from `IN_PROGRESS`:
1. `CUSTOMER_UNAVAILABLE`: Customer absent, unresponsive, or refused premises access.
2. `JOB_MISDESCRIBED`: Physical inspection revealed completely different scope than quoted.
3. `UNSAFE_CONDITIONS`: Hazardous wiring, structural instability, or personal safety threat.
4. `RESOURCES_UNAVAILABLE`: Specialized replacement parts unavailable in local market.
5. `OTHER`: Any other cause, requiring minimum 10 characters of explanatory text.

---

## 5. Telemetry, Routing & Realtime Communications

### 5.1 Geolocation Privacy & Coordinate Redaction
- When a booking is in `REQUESTED` status, providers in the browsing pool see only the customer's **general neighborhood and approximate distance**. Precise latitude and longitude are redacted by `BookingsService.getBookingById()`.
- Precise doorstep coordinates are only unredacted and revealed to the provider **after** the provider accepts the job (`ASSIGNED`).
- Customer location coordinates are never shared with other third-party providers.

### 5.2 Provider Route & OpenStreetMap Telemetry
- Providers broadcast live coordinates via WebSocket `location-update` or HTTP `PUT /provider-profile/me/location`.
- The customer tracking screen renders route polylines using OpenStreetMap raster tiles.
- Telemetry streams are cached in Redis with a 15-second TTL. If no GPS update is received within 60 seconds, the client UI displays a `"Signal Stale"` warning beacon.

### 5.3 Audio Call State Machine
FixNow includes an in-app WebRTC/SIP audio signaling subsystem:
```
[Initiate] ──► INITIATED ──► RINGING ──► CONNECTED ──► ENDED (Terminal)
                   │             │
                   ▼             ▼
               REJECTED       TIMED_OUT (Terminal)
```
- Calls are restricted strictly to active bookings (`ASSIGNED`, `EN_ROUTE`, `IN_PROGRESS`).
- Call session records calculate exact duration in seconds for quality audits.
- *Known Limitation:* While backend handlers and entities are fully operational, the mobile repository `HttpCallRepository` is currently unwired (`GAP-51`).

---

## 6. Financial Workflows, Payments & Escrow

### 6.1 Payment Authorization & Verification Boundary
FixNow integrates Razorpay as its authoritative payment gateway:
1. **Trigger:** Payments are strictly prohibited until a booking reaches `COMPLETED` status.
2. **Order Creation:** `POST /payments/orders` creates an order with Razorpay. Receipt is deterministically pinned as `booking:<bookingId>`.
3. **Escrow Hold:** Customer pays via UPI, Card, NetBanking, or Wallet. Funds are held in platform escrow.
4. **Cryptographic Verification:** Upon checkout completion, client submits `orderId`, `paymentId`, and `signature`. The backend computes `HMAC-SHA256(orderId + "|" + paymentId, keySecret)` and verifies equality.
5. **Invoice Generation:** A tax invoice is generated with statutory GST breakdown and stored in `invoices`.

### 6.2 Webhook Security & Idempotency
- Incoming Razorpay webhooks (`POST /payments/webhook`) are throttled to 300/min.
- The backend verifies HMAC-SHA256 over the **raw request body buffer** before JSON deserialization.
- Replay attacks are rejected by querying `payment_events` for existing `(orderId, eventType, payloadDigest)` tuples.

### 6.3 Admin Refunds
- Customer refund requests are adjudicated by `finance_operator` or `operations_administrator`.
- `POST /admin/payments/orders/:id/refunds` requires a mandatory `Idempotency-Key` header.
- Orders must be in `PAID` status. Upon success, order transitions to `REFUNDED` and refund details are logged.

### 6.4 Provider Payout & Earnings Calculation
Platform commission is deducted before provider disbursement:
```
Gross Booking Amount = Total Minor (excl. GST)
Platform Commission  = round(Gross Amount × 0.15)  [15% Take Rate]
Provider Payout Net  = Gross Amount - Platform Commission
```
Earnings reports aggregate settled bookings and display pending bank transfer batches.

---

## 7. Ratings, Complaints & Trust Adjudication

### 7.1 Review Submission & Moderation
- Customers can submit a review (1 to 5 stars, optional comment) only once per completed booking.
- Reviews default to `PENDING_MODERATION` status.
- Review photos undergo ClamAV malware scanning and automated vision moderation before appearing on provider public profiles.

### 7.2 Service Guarantee & 30-Day Warranty
FixNow provides an automatic 30-day service guarantee on all completed bookings:
- If a repaired appliance or electrical fixture fails within 30 days, the customer can submit a claim via `POST /guarantees/claims`.
- Supporting evidence URLs are attached.
- If approved by support staff, the platform dispatches a **Zero-Cost Re-Service Booking** (`is_guarantee_claim = true`, `total_amount_minor = 0`) assigned to a senior technician.

### 7.3 Formal Complaints & Appeal Lifecycle
Disputes and billing disagreements follow the formal complaints workflow:
```
PENDING ──► INVESTIGATING ──► RESOLVED
   │              │
   ▼              ▼
DISMISSED     ESCALATED ──► APPEAL_PENDING ──► APPEAL_RESOLVED
```
- Every transition creates an immutable record in `complaint_audits`.
- Support agents can request instant callbacks and attach diagnostic evidence.

---

## 8. Emergency SOS Dispatch Engine

For critical hazards (gas leaks, electrical fires, burst pipes), FixNow implements an emergency dispatch mechanism:
- **Safety Hold:** Customer must hold the SOS button continuously for 3 full seconds to prevent accidental triggers.
- **Limit:** Maximum 1 open emergency request per customer enforced via database constraint.
- **Wave Expansion Algorithm:**
  - **Wave 1 (0 to 60 seconds):** Dispatches push prompts to verified emergency technicians within a 3km radius.
  - **Wave 2 (60 to 120 seconds):** If unaccepted, the background engine expands dispatch radius to 6km.
  - **Wave 3 (120 to 180 seconds):** Radius expands to 12km, and the operations control tower receives an audio alert.
  - **Timeout:** If no technician accepts within 300 seconds, the request escalates to direct phone hotline routing.

---

## 9. Unresolved Product Policies & Governance Questions

1. **Cancellation Fee Liability on En-Route Abort:**
   - The customer terms state that cancellations while the provider is `EN_ROUTE` incur a ₹100 flat fee. However, the backend currently processes full cancellation without deducting or capturing the fee (`UNRESOLVED`).
2. **Review Photo Comma Delimitation in Database:**
   - In `guarantee_claims`, `evidence_urls` is stored as TypeORM `simple-array` (comma-separated strings). URLs containing query parameters with commas become corrupted upon deserialization (`GAP-15`).
3. **Provider Background Check Expiry:**
   - No automated cron or alert exists to trigger provider re-verification when police verification certificates exceed 365 days of validity (`UNRESOLVED`).
4. **Escrow Holding Window:**
   - The policy window for holding provider earnings in escrow before releasing payout is ambiguously documented between 24 hours and 72 hours (`UNRESOLVED`).
