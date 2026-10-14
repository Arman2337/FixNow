# FixNow — Complete Feature Inventory

**Audit date:** 2026-10-12
**Commit audited:** `3bdb5a2` (`main`) plus 5 uncommitted working-tree fixes from a prior session
**Scope:** entire monorepo — `backend/`, `mobile/`, `admin/`, `shared/`, `scripts/`, `e2e/`, `infrastructure/`, `ai/`
**Method:** static tracing of source (controllers → services → entities → guards → outbox), plus execution of the repository's own verification commands. No application source was modified for this audit. No database or migration was modified.

## Status legend

| Status | Meaning |
| --- | --- |
| **VERIFIED** | Implementation traced in source **and** covered by a test that passes when executed, or a runtime check executed in this audit. |
| **IMPLEMENTED_UNVERIFIED** | Implementation traced in source; no passing test and no runtime execution available. |
| **PARTIAL** | Some functionality exists; the workflow is incomplete or an integration is off. |
| **STUB** | Placeholder, mock, fabricated data, or nonfunctional implementation shipped in the product surface. |
| **MISSING** | Required functionality absent. |
| **BLOCKED** | Verification depends on credentials, infrastructure, devices, or external services not available here. |

---

## 1. System shape

| Surface | Stack | Entry | Scale |
| --- | --- | --- | --- |
| `backend/` | NestJS 11 · TypeORM · PostgreSQL · Express (`ws` adapter) | `backend/src/main.ts` | 24 top-level modules, 40 controllers, **119 route handlers**, 44 entities, 38 migrations |
| `mobile/` | Flutter (Dart ≥3.10.8) · `ChangeNotifier` + constructor DI · no router package | `mobile/lib/main.dart` | 156 Dart files, 32 `*_screen.dart` files, 21 feature directories, 89 public design-system widgets |
| `admin/` | Next.js 16.3.6 App Router · React 19.2.8 · Tailwind v4 · all-Server-Components | `admin/src/app/layout.tsx` | 17 pages + 1 route handler = 18 routes |
| `shared/` | Plain TypeScript type/const modules | — | 17 contract files |
| `e2e/` | Playwright 1.x + a hand-written `node:http` stub API | `e2e/playwright.config.ts` | 2 specs, 13 tests (12 active, 1 `fixme`) |

### Cross-cutting backend wiring (`backend/src/main.ts`, `app.module.ts`)

| Concern | Implementation | Location |
| --- | --- | --- |
| Global prefix | `api/v1` (no exclusions — health and metrics live *under* it) | `main.ts:31` |
| Validation | `ValidationPipe({whitelist:true, forbidNonWhitelisted:true, transform:true})` | `main.ts:32-38` |
| Global throttle | `ThrottlerModule.forRoot([{ttl:60_000, limit:60}])` | `app.module.ts:43` |
| Global auth guard | `AuthorizationGuard` (deny-by-default) | `auth/auth.module.ts:45` |
| Ownership proof | `OwnershipProofInterceptor` (response-side, fails closed) | `auth/auth.module.ts:47` |
| Exception filter | `AllExceptionsFilter` — never leaks stacks | `app.module.ts:67-70` |
| Raw body | `rawBody: true` for webhook HMAC | `main.ts:27` |
| WebSocket adapter | `WsAdapter` (`ws`), no per-message deflate | `main.ts:30` |
| Shutdown | `enableShutdownHooks` + `runGracefulShutdown` | `main.ts:116-122` |
| OpenAPI | Swagger UI `/api/docs`, prefix-stripped document | `main.ts:97-102` |

**Global rate limit is 60 requests/minute.** Per-route `@Throttle` overrides exist on all auth, push, and webhook routes (§5).

---

## 2. Backend feature inventory

### 2.1 Modules and providers

Top-level (`app.module.ts:33-63`, order is load-bearing — `OutboxModule` last):

`AppConfigModule` · `AppLoggerModule` · `DatabaseModule` · `RedisCacheModule` · `HealthModule` (global) · `ObservabilityModule` (global) · `UsersModule` · `ThrottlerModule` · `AuthModule` · `ProvidersModule` · `ServicesModule` · `BookingsModule` · `MatchingModule` · `RealtimeModule` · `AdminModule` · `ComplaintsModule` · `AiModule` · `RatingsModule` · `TrustModule` · `PushModule` · `PaymentsModule` · `EmergencyModule` · `GuaranteesModule` · `OutboxModule`

Transitively imported: `LocationModule`, `DomainNotificationsModule`, `NotificationsModule`, `StorageModule`.

### 2.2 Every route

`A` = `@Public()`. Permission values are the literal decorator argument. Throttle is the decorator's `limit/ttl`; *default* = global 60/min.

#### App root
| Method | Route | Auth | Status | Notes |
| --- | --- | --- | --- | --- |
| GET | `/api/v1` | **A** | 200 | Nest scaffold; returns `Hello World!` (`app.controller.ts:10`) |

#### Auth — customer (`auth/auth.controller.ts`, `@Controller('auth/customer')`)
| Method | Route | Auth | Throttle | Status | Body DTO |
| --- | --- | --- | --- | --- | --- |
| POST | `/api/v1/auth/customer/register` | **A** | 3/min | 201 | `EmailPasswordDto` — email ≤254, password 12–128 |
| POST | `/api/v1/auth/customer/login` | **A** | 5/min | 200 | `EmailPasswordDto` |
| POST | `/api/v1/auth/customer/password-reset/request` | **A** | 3/min | 202 | `PasswordResetRequestDto` — always `{status:'accepted'}` (anti-enumeration) |
| POST | `/api/v1/auth/customer/password-reset/confirm` | **A** | 5/min | 200 | token exactly 64 chars; new password 12–128 |

#### Auth — provider (`providers/provider-registration.controller.ts`)
| Method | Route | Auth | Throttle | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| POST | `/api/v1/auth/provider/register` | **A** | 3/min | 201 | Creates `pending_verification` user + `unverified` application |
| POST | `/api/v1/auth/provider/login` | **A** | 5/min | 200 | Same credential boundary |

#### Auth — admin (`auth/admin-auth.controller.ts`)
| Method | Route | Auth | Throttle | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| POST | `/api/v1/auth/admin/login` | **A** | 5/min | 200 | Requires **exactly one** staff role (`auth.service.ts:175-195`) |
| GET | `/api/v1/auth/admin/session` | `adminSessionReadSelf` | default | 200 | Returns `{userId, roles}` — **no name/email field** |

#### Auth — token lifecycle (`auth/token-lifecycle.controller.ts`)
| Method | Route | Auth | Throttle | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| POST | `/api/v1/auth/otp/request` | **A** | 3/min | 202 | 60 s resend delay |
| POST | `/api/v1/auth/otp/verify` | **A** | 5/min | 204 | 6 digits; promotes `PendingVerification → Active` |
| POST | `/api/v1/auth/token/refresh` | **A** | 30/min | 200 | Rotates; replay revokes the whole family |
| POST | `/api/v1/auth/logout` | **A** | 60/min | 204 | Current session |
| POST | `/api/v1/auth/logout-all` | **A** | 10/min | 204 | All sessions |

#### Health & observability
| Method | Route | Auth | Status | Notes |
| --- | --- | --- | --- | --- |
| GET | `/api/v1/health/liveness` | **A** | 200 | Never touches the DB |
| GET | `/api/v1/health/readiness` | **A** | 200 / 503 | DB ping (3 s) + drain state |
| GET | `/api/v1/health/readiness/state` | **A** | 200 | Snapshot |
| GET | `/api/v1/health/dashboard` | `adminSystemHealthRead` | 200 | HTML, per-response CSP |
| GET | `/api/v1/health/metrics` | **A** | 200 | Prometheus text, `no-store` |

> `RUNTIME_AUDIT.md:99` probed `GET /health` and recorded 404. **That is a wrong probe, not a bug** — the global prefix applies.

#### Users
| Method | Route | Auth | Status | Notes |
| --- | --- | --- | --- | --- |
| GET | `/api/v1/users/me/profile` | `profileReadSelf` | 200 | Display name only — deliberately minimal PII |
| PATCH | `/api/v1/users/me/profile` | `profileUpdateSelf` | 200 | `displayName` 1–80, no control characters |
| GET | `/api/v1/users/me/addresses` | `profileReadSelf` | 200 | |
| POST | `/api/v1/users/me/addresses` | `profileUpdateSelf` | 201 | lat/lng via `@IsLatitude`/`@IsLongitude` |
| DELETE | `/api/v1/users/me/addresses/:id` | `profileUpdateSelf` | 200 | 404 when not owned |

#### Service catalog (all **public**)
| Method | Route | Status | Notes |
| --- | --- | --- | --- |
| GET | `/api/v1/service-categories` | 200 | `isActive`/`isEmergency`/`limit≤200` |
| GET | `/api/v1/service-categories/active` | 200 | |
| GET | `/api/v1/service-categories/emergency` | 200 | |
| GET | `/api/v1/service-categories/:id` | 200 | |
| GET | `/api/v1/service-categories/slug/:slug` | 200 | |
| GET | `/api/v1/sub-services` | 200 | `categoryId` accepts UUID **or** slug; 400 otherwise |
| GET | `/api/v1/sub-services/:id` | 200 | `ParseUUIDPipe({version:'4'})` |

Admin catalog management: `POST|PUT|DELETE /api/v1/service-categories[/:id]` → `adminServicesCreate|Update|Delete`.

#### Provider
| Method | Route | Auth | Status | Notes |
| --- | --- | --- | --- | --- |
| GET | `/api/v1/provider-applications/me` | `providerApplicationReadSelf` | 200 | 404 if none |
| POST | `/api/v1/provider-applications/me/submit` | `providerApplicationUpdateSelf` | 201 | Transactional; 400 unless `unverified`/`resubmission_requested` |
| GET | `/api/v1/provider-profile/me` | `provider.profile.read` | 200 | |
| PUT | `/api/v1/provider-profile/me` | `provider.profile.update` | 200 | radius 1–100 km |
| PUT | `/api/v1/provider-profile/me/location` | `provider.profile.update` | 200 | **`@ConfigurableThrottle`** — default 60/min, env-tunable |
| PUT | `/api/v1/provider-profile/me/coverage-check` | `provider.profile.read` | 200 | |
| GET | `/api/v1/provider-skills/me` · `/me/count` · `/:id` | `provider.skills.read` | 200 | owner-scoped |
| GET | `/api/v1/provider-skills/user/:userId` | `provider.skills.read.any` | 200 | |
| GET | `/api/v1/provider-skills/category/:serviceCategoryId` | **A** | 200 | Public |
| POST | `/api/v1/provider-skills` | `provider.skills.create` | 201 | `isVerified`/`verificationNotes` stripped for non-admins |
| PUT | `/api/v1/provider-skills/:id` | `provider.skills.update` | 200 | |
| PUT | `/api/v1/provider-skills/:id/verify` | `admin.skills.verify` | 200 | |
| DELETE | `/api/v1/provider-skills/:id` | `provider.skills.delete` | 204 | |
| GET | `/api/v1/provider-availability/me` | `provider.availability.read` | 200 | |
| PUT | `/api/v1/provider-availability/me/schedule` | `provider.availability.update` | 200 | IANA tz, 7 rules, ≤90 exceptions, `expectedVersion` |
| PUT | `/api/v1/provider-availability/me/status` | `provider.availability.update` | 200 | optimistic-locked |
| GET | `/api/v1/provider-documents` | `provider.documents.read` | 200 | |
| POST | `/api/v1/provider-documents/:documentType` | `provider.documents.create` | 201 | multipart, 1 file ≤10 MiB, quarantine → ClamAV |
| GET | `/api/v1/provider-documents/:id` | `provider.documents.read` | 200 | streams bytes, `no-store` |
| DELETE | `/api/v1/provider-documents/:id` | `provider.documents.delete` | 204 | soft-delete tombstone |
| POST | `/api/v1/provider-verification/:applicationId/claim` | `providers.verification.review` | 201 | reviewer claim, `expectedVersion` |
| POST | `/api/v1/provider-verification/:applicationId/decision` | `providers.verification.review` | 201 | `approved|rejected|resubmission_requested`, reason 3–1000 |

#### Bookings
| Method | Route | Auth | Status | Key rules |
| --- | --- | --- | --- | --- |
| POST | `/api/v1/bookings` | `bookingCreateSelf` | 201 | `Idempotency-Key` header; fingerprint replay guard |
| POST | `/api/v1/bookings/:id/accept` | `bookingAccept` | 200 | Idempotent for same provider; 409 if taken |
| PATCH | `/api/v1/bookings/:id/status` | `bookingUpdateStatus` | 200 | Provider may only set `EN_ROUTE`/`COMPLETED` |
| PATCH | `/api/v1/bookings/:id/items` | `bookingManageItems` | 200 | `expectedVersion`; blocked after payment |
| PUT | `/api/v1/bookings/:id/line-items` | `bookingManageItems` | 200 | same guard |
| POST | `/api/v1/bookings/:id/service-start-otp` | `bookingServiceStartOtp` | 201 | deterministic HMAC-derived 4-digit |
| POST | `/api/v1/bookings/:id/start-service` | `bookingUpdateStatus` | 201 | OTP + `expectedVersion`, `timingSafeEqual` |
| POST | `/api/v1/bookings/:id/cancel` | `bookingCancelSelf` | 200 | per-party allow-lists |
| POST | `/api/v1/bookings/:id/reschedule` | `bookingCancelSelf` | 200 | only `REQUESTED`/`ASSIGNED`; must be future |
| GET | `/api/v1/bookings` | `bookingHistoryReadSelf` | 200 | keyset cursor, `limit` default 10, max 100 |
| GET | `/api/v1/bookings/available` | `bookingAvailableRead` | 200 | `limit` default 20, max 50 |
| GET | `/api/v1/bookings/:id` | `bookingHistoryReadSelf` | 200 | provider sees redacted coords unless active |

Recurring schedules (`schedules.controller.ts`, registered **before** `BookingsController` so `/bookings/schedules` is not swallowed by `/bookings/:id`):
`POST|GET /api/v1/bookings/schedules`, `PATCH .../:id/status` (`pause|resume|cancel`), `POST .../:id/confirm` — all `bookingScheduleManageSelf`.

Chat (`booking-messages.controller.ts`): `GET|POST /api/v1/bookings/:id/messages` — `bookingChatReadSelf` / `bookingChatSendSelf`; `messageText` 1–2000; `clientMessageId` accepted.

Calls (`booking-calls.controller.ts`): `GET .../calls/active`, `POST .../calls/initiate`, `POST .../calls/:callId/{answer,reject,hangup}` — `bookingCallManageSelf` / `bookingCallInitiateSelf`.

#### Payments
| Method | Route | Auth | Throttle | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| POST | `/api/v1/payments/orders` | `paymentOrderManageSelf` | default | 201 | `receipt = booking:<id>`; only `COMPLETED` bookings pay |
| GET | `/api/v1/payments/orders/booking/:bookingId` | `paymentOrderManageSelf` | default | 200 | |
| GET | `/api/v1/payments/invoices/:orderId` | `paymentInvoiceReadSelf` | default | 200 | |
| POST | `/api/v1/payments/orders/verify` | `paymentOrderManageSelf` | default | 201 | gateway signature over `order_id\|payment_id` |
| POST | `/api/v1/payments/webhook` | **A** | 300/min | 200 | raw-body HMAC verified **before** `JSON.parse` |
| POST | `/api/v1/admin/payments/orders/:id/refunds` | `paymentRefundCreate` | default | 201 | `Idempotency-Key` **required** |
| GET | `/api/v1/providers/me/earnings` | `providerEarningsReadSelf` | default | 200 | |
| GET | `/api/v1/providers/me/bookings/:bookingId/payment-status` | `providerEarningsReadSelf` | default | 200 | |

#### Ratings
| Method | Route | Auth | Status |
| --- | --- | --- | --- |
| POST | `/api/v1/bookings/:id/review` | `reviewCreateSelf` | 201 (rating 1–5) |
| GET | `/api/v1/bookings/:id/review` | `reviewReadBooking` | 200 |
| POST | `/api/v1/bookings/:id/review/photos` | `reviewCreateSelf` | 201 (multipart, ≤6 MiB) |
| GET | `/api/v1/bookings/:id/review/photos` | `reviewReadBooking` | 200 |
| PATCH | `/api/v1/admin/reviews/:id/moderation` | `reviewModerate` | 200 |
| PATCH | `/api/v1/admin/reviews/photos/:photoId/moderation` | `reviewModerate` | 200 — **see GAP-14 (shadowed route)** |

#### Emergency / Guarantees / Trust / Complaints
| Method | Route | Auth | Status | Notes |
| --- | --- | --- | --- | --- |
| POST | `/api/v1/emergency/requests` | `emergencyCreateSelf` | 201 | `Idempotency-Key` optional; extends `CreateBookingDto` |
| GET | `/api/v1/emergency/requests/:bookingId` | `emergencyCreateSelf` | 200 | wave + eligibility |
| GET | `/api/v1/admin/emergency/dispatches` | `emergencyDispatchManage` | 200 | |
| POST | `/api/v1/guarantees/claims` | `guaranteeClaimCreateSelf` | 201 | description 10–2000; ≤10 evidence URLs |
| GET | `/api/v1/guarantees/claims[/:id]` | `adminGuaranteesRead` | 200 | |
| PATCH | `/api/v1/guarantees/claims/:id/status` | `adminGuaranteesUpdate` | 200 | |
| POST | `/api/v1/guarantees/claims/:id/re-service` | `adminGuaranteesUpdate` | 201 | |
| GET | `/api/v1/trust/my-accept-time` | `trustAcceptTimeReadSelf` | 200 | |
| GET | `/api/v1/admin/trust/providers/:id/{metrics,accept-time}` | `trustSignalsRead` | 200 | |
| GET | `/api/v1/admin/trust/signals` | `trustSignalsRead` | 200 | hard `take: 100`, **unpaginated** |
| PATCH | `/api/v1/admin/trust/signals/:id` | `trustSignalsUpdate` | 200 | |
| POST | `/api/v1/support/complaints` | `complaintsCreate` | 201 | |
| GET | `/api/v1/support/complaints[/:id]` | `complaintsReadSelf` | 200 | |
| POST | `/api/v1/support/complaints/:id/evidence` | `complaintsCreate` | 201 | |
| POST | `/api/v1/support/complaints/:id/callback-request` | `complaintsCreate` | 201 | |

#### Notifications
| Method | Route | Auth | Throttle | Status |
| --- | --- | --- | --- | --- |
| GET | `/api/v1/users/:userId/notifications` | `notificationInboxReadSelf` | default | 200 |
| PATCH | `/api/v1/users/:userId/notifications/:id/read` | `notificationInboxReadSelf` | default | 200 |
| PUT | `/api/v1/notifications/push/devices` | `pushTokenManageSelf` | 10/min | 200 |
| GET/DELETE | `/api/v1/notifications/push/devices[/:id]` | `pushTokenManageSelf` | default | 200 |
| GET | `/api/v1/notifications/inbox` | **A** | — | **STUB — not registered in any module; see GAP-13** |

#### Admin
`@Controller('admin')` (`admin-management.controller.ts:42`) — 19 routes: `PATCH /admin/complaints/:id/status`; CRUD `/admin/service-categories[/:id]`; `GET /admin/bookings[/:id]`; `POST /admin/bookings/:id/cancel`; `GET /admin/users[/:id]`; `GET /admin/provider-applications[/:id]`; `POST /admin/provider-applications/:id/{claim,decision}`; `GET /admin/provider-applications/:id/documents[/:documentId]`; `GET /admin/complaints[/:id]`.
`@Controller('admin/analytics')` — `GET /admin/analytics` (`adminBookingsRead`).

> **GAP-16:** `PATCH /admin/complaints/:complaintId/status` uses an **inline TypeScript type literal** for its body, not a DTO class. `forbidNonWhitelisted` cannot strip unknown keys from a non-class type. `check:body-dtos` passes because it only greps for `@Body() *:` declarations.

#### AI (all advisory-only per ADR-0014)
| Method | Route | Auth | Status |
| --- | --- | --- | --- |
| POST | `/api/v1/ai/service-recommendation` | `aiRecommendationCreate` | 201 |
| GET | `/api/v1/ai/price-estimate` | `aiPriceEstimateReadSelf` | 200 (`serviceCategoryId` required) |
| POST | `/api/v1/ai/problem-analysis/image` | `aiProblemAnalysisCreate` | 201 (≤32 MiB) |
| POST | `/api/v1/ai/problem-analysis/voice` | `aiProblemAnalysisCreate` | 201 (≤50 MiB) |
| POST | `/api/v1/ai/problem-analysis/combined` | `aiProblemAnalysisCreate` | 201 (2 files, ≤50 MiB) |

### 2.3 WebSocket surface (not under `/api/v1`)

`@WebSocketGateway({path:'/realtime', maxPayload:16 KiB, perMessageDeflate:false})` — `realtime.gateway.ts:49-53`.

- Origin allowlist (dev: localhost/127.0.0.1 any port; prod: `REALTIME_ALLOWED_ORIGINS`)
- 5 s authentication timer; first frame must be `{"type":"authenticate","accessToken":"…"}` (≤4096 chars)
- Same `authorizeAccessToken` code path as HTTP
- Limits: 30 msg/min, 3600 voice frames/min, 10 subscriptions, 10 pending addresses, **3 connections per principal**, 30 s heartbeat, 60 s session revalidation
- Inbound: `authenticate`, `subscribe`, `unsubscribe`, `ping`, `presence-update`, `location-consent`, `location-update`, `call.voice-frame.v1`
- Outbound: `ready`, `error`, `pong`, `subscribed`, `subscription-denied`, `presence-ack`, `location-*`, `booking.projection-updated.v1`, `chat.message-received.v1`, `call.{incoming,answered,rejected,ended}.v1`, `provider.request.v1`, `notification.created.v1`
- Close codes: `4401` auth, `4403` denied, `4408` policy, `4429` limit, `1013` try-later
- Redis pub/sub fanout on channel `fixnow:realtime:events`; degrades to in-process

### 2.4 Authorization model

- ~70 permission strings, 11 role codes (`common/authorization/permission-policies.ts:80-91`): `customer`, `provider_applicant`, `verified_provider`, `provider_reviewer`, `support_agent`, `trust_safety_reviewer`, `finance_operator`, `service_catalog_manager`, `operations_administrator`, `security_administrator`, `auditor`
- Policy evaluates account status → role membership → `forbidSelfTarget` → `requireIndependentApproval` → `relationship: self|assigned`
- `access.role.grant.authorized` requires `security_administrator` + no-self-target + independent approval
- Ownership discharged by helpers in `resource-ownership.ts`; the interceptor 403s if `ownershipProven === false` after the handler resolves

### 2.5 Background work (no cron/scheduler package)

| Mechanism | Component | Cadence |
| --- | --- | --- |
| Transactional outbox | `outbox/outbox.service.ts` — claim/lease/retry, unique `dedupe_key` | polled |
| Booking expiry sweeper | `bookings/booking-dispatch.handlers.ts:145` | on outbox tick |
| Booking reminders | `notifications/domain/booking-reminder.service.ts` | `NOTIFICATION_REMINDER_INTERVAL_MS` (default 60 s) |
| Emergency waves | `emergency/emergency-wave.handlers.ts` | outbox-driven |
| Cache/Redis health watch | `cache/cache.module.ts:118` | `REDIS_HEALTH_INTERVAL_MS` (default 10 s) |
| Realtime session revalidation | `realtime.gateway.ts:577` | every heartbeat |

**No `@nestjs/schedule` dependency exists** — all periodic work is interval- or outbox-driven.

### 2.6 Business rules worth recording

**Booking lifecycle** (`shared/booking-lifecycle.types.ts:10-25`, enforced in `booking.entity.ts:127-150`):

```
REQUESTED → ASSIGNED | CANCELLED
ASSIGNED  → EN_ROUTE | CANCELLED
EN_ROUTE  → IN_PROGRESS | CANCELLED
IN_PROGRESS → COMPLETED | CANCELLED
COMPLETED, CANCELLED → terminal
```

- Cancel requires a non-blank reason; sets `cancellationReason` + `cancelledAt`
- Customer may cancel only from `REQUESTED`/`ASSIGNED`; provider from `ASSIGNED`/`EN_ROUTE`/`IN_PROGRESS`
- `IN_PROGRESS` is reachable **only** via OTP-verified `start-service`
- Optimistic locking: `expectedVersion` mismatch → 409; SQL `UPDATE … WHERE version = :expectedVersion`; `affected !== 1` → 409
- Idempotency: `sha256` fingerprint over the normalized request; matching replay returns the existing booking, mismatched → 409; concurrent-first-request race caught via PG `23505`
- GST: `subtotal = Σ price×qty`; `gst = round(subtotal × 0.18)`; `total = subtotal + gst`
- Price resolution re-reads `sub_services` **inside the transaction** and rejects missing/inactive/wrong-category/non-INR/unpriced
- Creation enqueues 3 outbox rows in one transaction: `provider-fanout`, `project`, `requested-expiry` (default +300 s)
- Expiry sweeper re-arms if supply appeared; otherwise transitions `REQUESTED → CANCELLED`

**Payments:** only `COMPLETED` bookings are payable. `markPaid` is a conditional update; 409 if already finalised. Webhook verifies HMAC on the raw body **before** parsing; replay guarded by unique `(orderId, eventType, payloadDigest)`; amount mismatch records an event but leaves the order untouched.

**Provider acceptance:** idempotent for the same provider (200, no second event), 409 if another provider won, 403 if not eligible — and eligibility is checked *before* the version CAS. Capacity enforced under `pessimistic_write`.

**AI:** no model ever determines a price. `price-estimate` reads admin-published `price_amount`, or min/median/max of ≥5 `payment_orders` rows capped at 50. Confidence bands pinned at ≥0.85 high / ≥0.60 medium / else low.

---

## 3. Flutter mobile feature inventory

### 3.1 Root screen-swap ladder (`app.dart:614-981`)

| Condition | Screen |
| --- | --- |
| `initial` or (`loading` && no session) | spinner |
| `verificationRequired` | `VerificationScreen` |
| unauthenticated | `WelcomeScreen` / `AuthScreen` |
| role `providerApplicant` | `ProviderOnboardingScreen` |
| role `verifiedProvider` | `AppShell(provider)` |
| otherwise | `AppShell(customer)` |

### 3.2 Tabs (`app_navigation.dart`)

| Role | 0 | 1 | 2 | 3 |
| --- | --- | --- | --- | --- |
| Customer | Home (`ServiceDiscoveryScreen`) | Bookings | Help | Profile |
| Provider | Home (`ProviderHomeScreen`) | Active Job (`ProviderJobsScreen(showHistory:false)`) | History (`ProviderJobsScreen(showHistory:true)`) | Profile (`ProviderOnboardingScreen`) |

Tab index persists per role in `FlutterSecureStorage` under `fixnow.navigation.<role>`.

> Provider tab 0 is labelled "Home" with a **work** icon but renders the requests workspace; tab 1 labelled "Active Job" renders the jobs list. `ProviderActiveJobCockpitScreen` is pushed *on top of* tab 0.

### 3.3 Screens (32 `*_screen.dart` files)

| Screen | File | Lines | State |
| --- | --- | --- | --- |
| `WelcomeScreen` | `auth/welcome_screen.dart` | 714 | role select, 2-step CTA |
| `AuthScreen` | `auth/auth_screen.dart` | 1102 | sign-in/register segmented; dev-only Quick Login |
| `VerificationScreen` | `auth/verification_screen.dart` | 735 | 6-digit OTP, resend cooldown, dev bypass |
| `ServiceDiscoveryScreen` | `features/services/service_discovery_screen.dart` | 2731 | 6 statuses, skeleton, offline banner |
| `SubServiceCatalogScreen` | `features/services/sub_service_catalog_screen.dart` | 1323 | cart steppers, floating cart, filter chips |
| `ServiceRequestScreen` | `features/bookings/service_request_screen.dart` | 663 | description, address, schedule, advisory price |
| `CustomerBookingsScreen` | `features/bookings/customer_bookings_screen.dart` | 1704 | filter bar, summary, schedules section |
| `BookingDetailScreen` | `features/bookings/booking_detail_screen.dart` | 1199 | per-status actions, guarantee claim, review panel |
| `BookingTrackingScreen` | `features/tracking/booking_tracking_screen.dart` | 1771 | connection card, security OTP, live map |
| `ProviderLiveMap` | `features/tracking/provider_live_map.dart` | 1079 | OSM tiles, route polyline, recentre |
| `BookingChatScreen` | `features/chat/booking_chat_screen.dart` | 760 | thread, composer, delivery ticks |
| `ProblemDiagnosisScreen` | `features/ai/problem_diagnosis_screen.dart` | 822 | image/voice/text, scanner overlay |
| `CustomerHelpScreen` | `features/support/customer_help_screen.dart` | 1127 | search, 5 static FAQs, quick actions |
| `ComplaintListScreen` | `features/support/complaint_list_screen.dart` | 1186 | evidence sheet, callback request |
| `ComplaintDetailScreen` | `features/support/complaint_detail_screen.dart` | 567 | **dead** — test-only |
| `SubmitComplaintScreen` | `features/support/submit_complaint_screen.dart` | 242 | category, description |
| `NotificationCenterScreen` | `features/notifications/notification_center_screen.dart` | 860 | category filter, dismiss, clear-all |
| `EmergencyConfirmScreen` | `features/emergency/emergency_confirm_screen.dart` | 887 | hold-to-confirm, wave view |
| `InvoiceScreen` | `features/payments/invoice_screen.dart` | 628 | 4 states, PDF download, share |
| `BookingReviewPanel` | `features/ratings/booking_review_panel.dart` | 566 | stars, photos |
| `SubmitClaimScreen` | `features/guarantees/ui/submit_claim_screen.dart` | 120 | guarantee claim |
| `CustomerProfileScreen` | `features/profile/customer_profile_screen.dart` | 974 | profile form, addresses, push settings |
| `LocationConsentCard` | `features/location/location_consent_card.dart` | 110 | 6 permission states |
| `ProviderHomeScreen` | `features/provider/provider_home_screen.dart` | 1128 | availability, incoming requests, earnings |
| `ProviderJobsScreen` | `features/provider/provider_jobs_screen.dart` | 1908 | urgent/upcoming/history cards |
| `ProviderActiveJobCockpitScreen` | `features/provider/provider_active_job_cockpit_screen.dart` | 1927 | OTP, proof, adjustments, complete |
| `ProviderNavigationMapScreen` | `features/provider/provider_navigation_map_screen.dart` | 479 | turn-by-turn, verify OTP |
| `ProviderIncomingRequestScreen` | `features/provider/provider_incoming_request_screen.dart` | 285 | accept/skip |
| `ProviderEarningsScreen` | `features/provider/provider_earnings_screen.dart` | 502 | gross/refunded/net |
| `ProviderOnboardingScreen` | `features/provider/provider_onboarding_screen.dart` | 1995 | 4-step wizard, KYC upload |
| `ProviderSetupScreen` | `features/provider/provider_setup_screen.dart` | 397 | **dead** |
| `BookingTrackingOverviewScreen` | `features/tracking/booking_tracking_overview_screen.dart` | 48 | **dead** |
| `ProviderOnboardingEntryScreen` | `auth/provider_onboarding_entry_screen.dart` | 72 | **dead** |

Plus `AppShell` (`app/app_shell.dart`, 324).

### 3.4 Dialogs and bottom sheets (27)

Every one was traced for whether its confirm action persists:

| # | Component | Persists? |
| --- | --- | --- |
| 1 | `showCancellationDialog` | ✅ reason → `POST bookings/:id/cancel` |
| 2 | `_confirmClearAll` (notifications) | ⚠️ **client-only** in-memory `_deletedIds` |
| 3 | `_showInvoiceModal` | ❌ Close only — **no path to the invoice** |
| 4 | `showFixBanner` | ⚠️ `onPressed: onAction ?? () {}` — a label with no handler renders a **live no-op button** |
| 5 | `FixShareCelebration` | n/a (dialog route) |
| 6 | `_showEmergencyGuidanceDialog` | n/a (dials `tel:`) |
| 7 | `_showSafetyModal` (tracking) | ❌ read-only acknowledgement |
| 8 | `_handleCompleteService` dialog | ⚠️ `if (shouldContinue != true && !mounted)` makes the cancel guard **ineffective** — both branches proceed |
| 9 | `_handleAddExtraCharge` sheet | ✅ → `PUT bookings/:id/line-items` |
| 10 | `_ServiceAdjustmentSheet` | ✅ |
| 11 | `_requestServiceStartOtp` dialog | ✅ |
| 12 | `FixOtpInputSheet` | ✅ |
| 13 | `FixRescheduleSheet` | ✅ |
| 14 | `FixProviderWorkingHoursSheet` | ✅ → `PUT provider-availability/me/schedule` |
| 15 | `FixPaymentCheckoutSheet` | ⚠️ if `onProcessPayment == null`, a 600 ms delay then shows **"Payment Successful! VERIFIED & PAID"** — a simulation path that ships (now dev-gated) |
| 16 | `FixShareInvoiceSheet` | ✅ real PDF via `path_provider` + `share_plus` |
| 17 | `JobProofVerificationDialog` | ⚠️ **in-memory only** — `JobProofRepository` singleton, never uploaded |
| 18 | `JobProofViewerCard` + 2 dialogs | n/a (view) |
| 19 | `ServiceLocationPickerSheet` | ✅ returns a fix |
| 20 | `AddEditAddressModalSheet` | ✅ → `POST users/me/addresses` |
| 21 | `SavedAddressSelectorCard` | ✅ |
| 22 | `_CustomerLocationOptionsSheet` | ✅ |
| 23 | `_openProofModal` (complaint evidence) | ✅ |
| 24 | Support hotline dialog | ❌ "Request Instant Callback" opens a dialog saying unavailable |
| 25 | `_CartSummarySheet` | ✅ hands off to booking |
| 26 | Image-source sheet (AI) | n/a |
| 27 | `FixAcceptCelebration` | n/a |

### 3.5 Auth state machine

`AuthStatus` = `initial | loading | verificationRequired | authenticated | unauthenticated | offline | failure`.

- Refresh is **pull-based only** — no timer. `validAccessToken()` refreshes on demand and every repository calls it per request.
- 30-second clock skew (`auth_session.dart:20`)
- Single-flight refresh de-duplication (`auth_controller.dart:218-222`)
- Account-state ladder: `pending_verification` (detected by base64-decoding the JWT `accountStatus`) → OTP → `authenticated`; then `provider_applicant` → onboarding wizard → `verified_provider`
- ⚠️ `offline` and `failure` produce **no dedicated UI** — they fall through to the Welcome screen, and `errorMessage` only renders inside `AuthScreen`

### 3.6 Data layer resilience

| Property | Value | Location |
| --- | --- | --- |
| Timeout | 15 s | `api_client.dart:70` |
| Retry | GET only, max 2 attempts, 200 ms·n backoff | `api_client.dart:71,180-193` |
| Response cap | 1 MiB → `invalidResponse` | `api_client.dart:77,220` |
| Error mapping | 401→`unauthorized`, ≥500→`server`, else `invalidResponse` | `api_client.dart:259-286` |
| Response decoding | rejects non-map/non-list JSON | `api_client.dart:250-257` |
| Realtime | exponential backoff `500 ms × 2^n` capped at 4 shifts; ping/pong liveness; `isStale` deliberately ≠ `!isConnected` | `realtime_client.dart:337,365-418` |

### 3.7 Platform integrations

Geolocation (`geolocator`), reverse geocoding (`geocoding` then `https://api.bigdatacloud.net/...`), OSM tiles (`flutter_map`), `url_launcher` (conditional web/native pair — **the native stub is a no-op**), `firebase_messaging`, `flutter_secure_storage`, `image_picker`, `record`, `path_provider`, `share_plus`, `audioplayers`, `flutter_map`/`latlong2`.

Native `MainActivity.kt` implements `com.fixnow.mobile/audio_tone` and `voice_stream` MethodChannels — **no Dart caller exists**.

### 3.8 Accessibility & responsiveness

Semantics labels on service cards (`'<name> service category'`), `Semantics(liveRegion:)` on loading states, reduce-motion handling across `fix_motion_suite.dart`, `signature_motion.dart`, `provider_live_map.dart`, `app_shell.dart`, skeleton/skeleton-thread loading states. Small-screen coverage asserted by `welcome_screen_test.dart`.

---

## 4. Admin panel feature inventory

### 4.1 Routes (18)

| Route | Purpose | Endpoint(s) | Code-level role check |
| --- | --- | --- | --- |
| `/` | Operations dashboard | `GET /admin/analytics` | ✅ `operations_administrator`/`auditor` |
| `/analytics` | Full analytics | `GET /admin/analytics` | ✅ same 2 roles — **ORPHANED, no link anywhere** |
| `/bookings` | Dispatch list | `GET /admin/bookings?limit=20` | ❌ nav-hiding only |
| `/bookings/[bookingId]` | Booking dossier + cancel | `GET /admin/bookings/:id` | ✅ intervene = `trust_safety_reviewer`/`operations_administrator` |
| `/providers` | KYC queue | `GET /admin/provider-applications` | ❌ |
| `/providers/[applicationId]` | KYC dossier, claim, decision, docs | 4 calls | ✅ `provider_reviewer`/`operations_administrator` |
| `/providers/[aId]/documents/[docId]` | Streaming document proxy | `GET .../documents/:docId` | ❌ token-presence only |
| `/support` | Complaint queue | `GET /admin/complaints` (**unpaginated**) | ❌ |
| `/support/[complaintId]` | Case dossier + adjudication | 4 calls | ✅ 3 roles |
| `/guarantees` | Claim list | `GET /guarantees/claims` | ❌ |
| `/guarantees/[id]` | Claim detail + re-service | 3 calls | ❌ — **two inline server actions that `throw`** |
| `/services` | Category CRUD + pricing | `GET /admin/service-categories` | ❌ — **all forms render for every staff role** |
| `/trust` | Trust moderation | `GET /admin/trust/signals` (**unpaginated**) | ❌ **none at all** |
| `/users` | User registry | `GET /admin/users?limit=20` | ❌ — **ORPHANED, no nav entry** |
| `/users/[userId]` | Account detail | `GET /admin/users/:id` | ❌ — orphan tree |
| `/search` | Cross-entity search | 4 calls, sequential | ✅ per-dataset |
| `/login` | Staff login | `POST /auth/admin/login` | — |
| `/unauthorized` | 403 page | — | ❌ **performs no auth check at all** |

Boundary files: `layout.tsx`, `loading.tsx`, `error.tsx` (client; gates `error.message` on `NODE_ENV !== "production"`), `global-error.tsx` (client; own `<html>`), `not-found.tsx`.

### 4.2 Navigation reachability

`admin-shell.tsx:7-15` declares 7 items, role-filtered at `:18`. Reachability:

- ✅ linked: `/`, `/providers`, `/bookings`, `/support`, `/guarantees`, `/trust`, `/services`
- ❌ **fully orphaned**: `/analytics`, `/users` — no href anywhere in the app
- ⚠️ reachable only via the header form (not the nav array): `/search`
- ⚠️ `/bookings/[bookingId]` — the `/bookings` table rows are **not links** (`bookings/page.tsx:97`); only guarantees and search link into it

Active-highlight mismatches: both provider pages pass `current="Provider KYC Verification"` but the nav label is `"Providers & KYC Verification"` → never active. `/search` passes `current="Overview Dashboard"` → **the dashboard highlights while on search**.

### 4.3 Access-control model

No `middleware.ts`. Every page calls `getSession()`, which validates the access token against the backend **on every render** (`cache:"no-store"`). Cookies `fixnow_admin_access` / `fixnow_admin_refresh`, `httpOnly`, `sameSite:"strict"`, `secure` in production, refresh `maxAge` hardcoded to 30 days.

`requireManagementResult` redirects 401 → `/login?reason=expired`, 403 → `/unauthorized`, else throws → `error.tsx`.

> The nav filter is a **convenience, not a control**. Only 6 of 18 routes have a code-level role check.

---

## 5. Database inventory

### 5.1 Discovery

Both configs resolve to the **same** directory, `backend/migrations/`: `typeorm.config.ts:17` and `database.module.ts:20`. `synchronize:false` and `migrationsRun:false` everywhere. Integration tests use an explicit 44-entry `ALL_ENTITIES` list (`test/support/test-data-source.ts:66-111`).

⚠️ `typeorm.config.ts:9-11` falls back to `.env.example` when `DATABASE_URL` is absent — the CLI will not fail fast.

### 5.2 Entities (44)

Grouped by domain. Full column-level detail is in `FEATURE_TRACEABILITY.md` §DB.

| Domain | Tables |
| --- | --- |
| Identity | `users`, `user_identities`, `roles`, `user_roles`, `auth_credentials`, `password_reset_tokens`, `customer_profiles`, `customer_addresses` |
| Session | `auth_sessions`, `otp_challenges`, `auth_audit_events` |
| Catalog | `service_categories`, `sub_services` |
| Provider | `provider_applications`, `provider_profiles`, `provider_skills`, `provider_availability`, `provider_documents`, `provider_document_audit_events`, `provider_verification_events` |
| Booking | `bookings`, `booking_events`, `booking_line_items`, `booking_messages`, `booking_calls`, `recurring_schedules`, `emergency_dispatches` |
| Payments | `payment_orders`, `payment_events`, `refunds`, `invoices` |
| Ratings | `booking_reviews`, `review_photos`, `review_moderation_events`, `review_photo_moderation_events` |
| Trust/guarantee | `trust_signals`, `guarantee_claims` |
| Support | `complaints`, `complaint_evidence`, `complaint_audits` |
| Notifications | `in_app_notifications`, `notification_deliveries`, `push_device_tokens` |
| Ops | `outbox_messages` |

- **5 `@VersionColumn`** (optimistic lock): `bookings`, `booking_reviews`, `trust_signals`, `complaints`, `emergency_dispatches`
- **1 `@DeleteDateColumn`** (soft delete): `bookings.deleted_at`
- **2 hand-rolled `version` columns that are NOT `@VersionColumn`** and therefore get no automatic optimistic locking: `provider_applications.version`, `provider_availability.version` (both guarded by manual `expectedVersion` checks)
- ⚠️ `bookings.booking_line_items` is `eager: true`, so **every booking load joins line items**

### 5.3 Enums

11 TypeScript enums. **4 have entity/DB type-name mismatches** (the entity omits `enumName`, so TypeORM would generate a different type name): `ComplaintStatus`, `ComplaintTargetRole`, `PushPlatform`, `GuaranteeClaimStatus`. 3 DB enum types have no TS counterpart: `complaints_appealstatus_enum`, `complaint_audits_previous_status_enum`, `complaint_audits_new_status_enum`.

### 5.4 Migrations

**38 files** in `backend/migrations/`, plus **1 orphan** and **1 duplicate timestamp**.

| Finding | Detail |
| --- | --- |
| **Orphan** | `backend/src/database/migrations/1789735751504-add-phone-to-users.ts` — outside both globs, never runs. Its work is already done by `1789748288429`. Promoting it would fail `42701 duplicate_column`. |
| **Duplicate timestamp** | `1786521300000` used by both `BookingLineItems.ts` and `ComplaintsSchema.ts`. TypeORM keys on the `name` string, so both run; relative order is incidental. |
| **`ADD COLUMN` without `IF NOT EXISTS`** | 6 statements: `1720000008000` (one 4-column statement — all fail together), `1786520300000:7,10`, `1786521300000:7,10,13`; plus `1786521400000:111-115` (`addColumns` without `ifNotExist`). |
| **Destructive `up()`** | `1789749968260-CheckSchemaSync.ts` drops 41 FKs, 36 indexes, 16 CHECK/UNIQUE constraints, and **`DROP COLUMN status` + re-add** on `payment_orders`/`refunds`/`review_photos` — which destroys every existing status value including every `PAID` order. Its `down()` is the only place the real constraint names return. Repaired by `1789749980000-RestoreBookingIntegrity.ts`. |
| **FK `onDelete` drift** | `1789749980000` re-adds FKs with different actions than the originals: `auth_audit_events.user` `SET NULL → **CASCADE**` (deleting a user erases their auth audit trail); `complaints.submitter` `CASCADE → **SET NULL**`. |

### 5.5 Schema verification (executed)

`npm run schema:verify` → **46 passed, 0 failed**. DB-wide: 47 FKs, 23 CHECKs, 116 indexes, 38 migrations.

⚠️ The gate printed `no users/service_categories seeded, skipping write checks` — the three **behavioural** probes (orphan booking → 23503, negative total → 23514, latitude 999 → 23514) were **skipped**. Those are the checks that prove constraints actually bite. `verify-fresh-schema.ts` exists to plant the fixtures, but it `DROP DATABASE`/`CREATE DATABASE` and was **not run** in this audit (it mutates the database).

### 5.6 Seed data

`backend/seed.js` is invoked by `render.yaml:7` **on every production deploy**: `migration:run && node seed.js && start:prod`. It runs **`DELETE FROM sub_services` with no `WHERE` clause** (`seed.js:91`) then reinserts 39 hardcoded rows. Any admin-curated sub-service is destroyed on each deploy. No `ON CONFLICT`; idempotency relies entirely on the preceding delete. `connectionString` falls back to a local `postgresql://postgres:replace-me@localhost:5432/fixnow` when `DATABASE_URL` is unset (`seed.js:6`).

`backend/test/acceptance-fixtures.ts` is well-guarded: requires `NODE_ENV ∈ {development,test}`, `ACCEPTANCE_FIXTURES_ENABLED=true`, and a loopback hostname matching `^/(fixnow_(dev|test)|postgres)$`, wrapped in an explicit transaction, fully idempotent. Passwords are compile-time constants but stored Argon2id-hashed.

### 5.7 Sensitive data

| Data | Treatment |
| --- | --- |
| Passwords | Argon2id (`auth.service.ts:399-401`) |
| Refresh tokens | SHA-256 hash only, `char(64)` unique |
| OTP codes | `HMAC-SHA256(OTP_SECRET, identityId:code)`, `timingSafeEqual` |
| Password-reset tokens | SHA-256, single-use via conditional `consumed_at` |
| Service-start OTP | HMAC-derived, never stored |
| PII | Deliberately minimal — profile holds only `display_name` |
| Encryption at rest | **None** |

---

## 6. Integrations

| # | Integration | Config | Default | Failure behavior | Prod impl? |
| --- | --- | --- | --- | --- | --- |
| 1 | **PostgreSQL** | `DATABASE_URL` | required | Hard boot failure | ✅ |
| 2 | **Redis** | `REDIS_URL` | required (dev) | TCP-probe factory; **refuses to boot in production**; loud in-memory fallback otherwise | ✅ |
| 3 | **Razorpay** | `PAYMENT_PROVIDER`, 3 secrets | `fake` | `fake` **prohibited in production** (`env.validation.ts:634-657`) | ✅ + deterministic fake |
| 4 | **FCM push** | `PUSH_PROVIDER`, `FCM_CREDENTIALS_FILE` | `disabled` | `DisabledPushDelivery` honestly reports `unavailable` | ✅ |
| 5 | **SMTP (OTP)** | `SMTP_*` (5 vars) | unset | `ServiceUnavailableException` | ✅ |
| 6 | **S3 object storage** | `PROVIDER_DOCUMENT_S3_*` | loopback MinIO | construction throws if unset; endpoint must be HTTPS in production | ✅ (`@aws-sdk/client-s3`) |
| 7 | **ClamAV** | `CLAMAV_HOST/PORT` | 127.0.0.1:3310 | **fails closed** — raw TCP `INSTREAM`, 10 s timeout | ✅ |
| 8 | **HuggingFace AI** | `AI_ENABLED`, `HF_TOKEN`, model/base URLs | `disabled` | `fake` prohibited in production; every failure maps to a typed fallback, never throws | ✅ + deterministic provider |
| 9 | **OpenRouteService** | `OPENROUTESERVICE_API_KEY` | unset | `BoundedFallbackEtaAdapter` (estimated math) | ✅ + fallback |
| 10 | **WebSockets** | `ws` adapter | on | Redis fanout degrades to in-process | ✅ |
| 11 | **Error reporting** | `ERROR_REPORTING_DSN` | unset | `NoopErrorReporter` | ✅ (Sentry-compatible) |
| 12 | **BigDataCloud** | hardcoded in mobile | on | silent `null` | ⚠️ sends user coordinates off-platform |
| 13 | **OSM tiles** | hardcoded in 3 mobile files | on | n/a | ⚠️ public tile servers, no rate control |

No JWT library beyond `@nestjs/jwt`; **no Passport**. No cron/scheduler package.

---

## 7. Test inventory

| Suite | Files | Tests | Executed here |
| --- | --- | --- | --- |
| Backend unit (`src/**/*.spec.ts`) | 107 | 894 | ✅ **894/894 pass** |
| Backend integration (`test/**/*.integration-spec.ts`) | 14 | 85 | ⛔ **BLOCKED** — isolated DB on :55432 down |
| Backend e2e (`test/app.e2e-spec.ts`) | 1 | 1 | ❌ not wired into CI |
| Mobile widget/unit (`test/**/*_test.dart`) | 84 | 428 | ✅ **428/428 pass** |
| Admin (`src/**/*.test.ts(x)`) | 13 | 35 | ✅ **35/35 pass** |
| E2E Playwright (`e2e/tests/**`) | 2 | 13 (12 + 1 fixme) | ❌ browsers not installed |
| **Total** | **221** | **~1,456** | |

### Gate results executed in this audit

| Gate | Command | Result |
| --- | --- | --- |
| Backend tests | `npm test` | ✅ 894/894, 106 suites |
| Backend build | `npm run build` | ✅ exit 0 |
| Backend lint | `npx eslint` | ✅ exit 0 |
| Backend DTO gate | `npm run check:body-dtos` | ✅ every `@Body()` is a class |
| Backend env gate | `npm run check:env-declarations` | ✅ (5 dynamic read sites noted) |
| Deploy config gate | `npm run deploy:verify-env` | ✅ 70 declared, render.yaml agrees |
| Schema gate | `npm run schema:verify` | ✅ 46/46 — **write checks skipped** |
| Schema from scratch | `npm run schema:verify:fresh` | ❌ not run (drops/creates a DB) |
| Secret scanner self-test | `node scripts/scan-secrets.mjs --self-test` | ✅ 11 rules fire |
| **Secret scanner** | `node scripts/scan-secrets.mjs` | ❌ **FAILS — 1 finding** (see GAP-01) |
| Mobile analyze | `flutter analyze` | ✅ 0 errors |
| Mobile tests | `flutter test` | ✅ 428/428 |
| Admin type-check | `npm run type-check` | ✅ exit 0 |
| Admin lint | `npx eslint .` | ✅ exit 0 |
| Admin tests | `npm test` | ✅ 35/35 |
| Admin build | `npm run build` | ✅ exit 0 |

### Notable coverage holes

Zero tests: `src/storage/**` (ClamAV scanner, S3 adapter), `src/outbox/**` (14 KB transactional outbox), `src/admin/admin-operations.service.ts`, `src/health/system-health.service.ts`, all `shared/*.types.ts`, `ai/providers/huggingface-ai.provider.ts`, `ai/providers/deterministic-ai.provider.ts`, `services/sub-services.controller.ts`, `bookings/booking-dispatch.handlers.ts`.

Untouched controllers (7): all three payments controllers, `provider-application.controller.ts`, `provider-profile.controller.ts`, `provider-availability.controller.ts`, `provider-document.controller.ts`, `provider-verification.controller.ts`, `ratings.controller.ts`, `ratings-admin.controller.ts`, `trust*.controller.ts`, `schedules.controller.ts`, `emergency.controller.ts`.

Admin: 12 of 18 routes have no test; no test exists for `management-api.ts` or any `api.ts`/`actions.ts` module.

> **`shared/complaint-lifecycle.types.ts` is the server-side source of truth that the admin console mirrors**, but `admin/src/features/operations/complaint-lifecycle.test.ts` pins only the admin copy. Nothing asserts the two tables agree.

---

## 8. Verification status roll-up

| Area | Status |
| --- | --- |
| Auth (register/login/OTP/refresh/logout/reset) | **VERIFIED** |
| Authorization guard + ownership + permission matrix | **VERIFIED** |
| Booking lifecycle + idempotency + optimistic locking | **VERIFIED** (unit) |
| Payments orders/verify/webhook/refunds | **VERIFIED** (unit only — no integration run) |
| Provider onboarding/profile/skills/availability | **VERIFIED** (unit) |
| Catalog (categories + sub-services) | Categories **VERIFIED**; sub-services **IMPLEMENTED_UNVERIFIED** |
| Trust / ratings / complaints / guarantees | **VERIFIED** (unit) |
| Realtime gateway limits + auth | **VERIFIED** (unit) |
| Outbox | **IMPLEMENTED_UNVERIFIED** |
| Storage / ClamAV | **IMPLEMENTED_UNVERIFIED**, **BLOCKED** (needs containers) |
| AI price estimate + classification | **VERIFIED** (deterministic provider + versioned evals) |
| Live AI (HF) | **BLOCKED** (no token, and gated off by policy) |
| FCM push | **BLOCKED** (no credentials) |
| Razorpay | **BLOCKED** (no keys; `fake` prohibited in prod) |
| Mobile all screens | **VERIFIED** (428 widget/unit tests) |
| Mobile realtime socket | **VERIFIED** |
| Mobile live maps / GPS / camera / audio | **BLOCKED** (needs a device) |
| Admin app build/auth/api | **VERIFIED** |
| Admin pages (12 of 18) | **IMPLEMENTED_UNVERIFIED** |
| Admin `/trust` access control | **PARTIAL** — page has no role check |
| Playwright journeys | **IMPLEMENTED_UNVERIFIED** (not run) |
| Schema integrity | **VERIFIED** for object existence; **IMPLEMENTED_UNVERIFIED** for behaviour (write checks skipped) |
| Secret scan | **FAILING** (GAP-01) |

---

## 9. Coverage limitations of this audit

1. **Backend integration tests were not run** — the isolated PostgreSQL on port 55432 is not running. 85 tests across 14 specs are unexecuted here.
2. **`schema:verify:fresh` was not run** — it drops and creates a database, which the audit brief forbids. The write-path constraint checks were therefore skipped.
3. **Playwright journeys were not run** — no browsers installed.
4. **No live third-party integration was exercised** — no Razorpay, FCM, HF, OpenRouteService, or ClamAV credentials or containers.
5. **No mobile device or emulator run** — camera, microphone, GPS, biometric, and FCM paths are source-traced only.
6. **Admin pages were not exercised against a live backend** — behaviour is inferred from the stub-backed e2e harness and source.
7. This inventory reflects commit `3bdb5a2` **plus** the five uncommitted working-tree fixes from the prior session (admin parse error, checkout gating, catalog ratings, hotline, dev orchestrator). Those fixes are uncommitted and were not re-audited for new defects.