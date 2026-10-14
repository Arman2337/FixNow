# FixNow — Feature Traceability Matrix

**Audit date:** 2026-10-12 · **Commit:** `3bdb5a2` + 5 uncommitted working-tree fixes
**Companion documents:** `FEATURE_INVENTORY.md` (what exists), `FEATURE_GAPS.md` (what is missing/broken)

Every row cites the mobile screen or admin route, the backend endpoint, the affected tables, the tests that cover it, and a verification status defined in `FEATURE_INVENTORY.md` §Status legend.

**Legend** — `S` status: V=VERIFIED, U=IMPLEMENTED_UNVERIFIED, P=PARTIAL, S=STUB, M=MISSING, B=BLOCKED

---

## 1. Identity & Access

| ID | Feature / workflow | Mobile | Admin | Backend endpoint | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FN-001 | Customer registration | `AuthScreen` | — | `POST /auth/customer/register` | `users`,`user_identities`,`auth_credentials`,`user_roles`,`customer_profiles` | `auth/auth.service.ts:94-147` | `auth.service.spec` (12), `auth.integration-spec` | V |
| FN-002 | Customer login | `AuthScreen` | — | `POST /auth/customer/login` | `auth_credentials`,`users` | `auth/auth.service.ts:175-280` | `auth.service.spec`, `auth.integration-spec` | V |
| FN-003 | Provider registration | `AuthScreen` (role=provider) | — | `POST /auth/provider/register` | `users`,`provider_applications`,`user_roles` | `providers/provider-registration.controller.ts:11` | `provider-registration.controller.spec` | V |
| FN-004 | Provider login | `AuthScreen` | — | `POST /auth/provider/login` | `auth_credentials` | `auth.service.ts:175-195` | `auth.service.spec` | V |
| FN-005 | Staff (admin) login | — | `/login` | `POST /auth/admin/login` | `auth_credentials`,`user_roles` | `auth/admin-auth.controller.ts:25` | `admin-auth.controller.spec`, `auth/actions.test.ts` | V |
| FN-006 | Session introspection | — | every page | `GET /auth/admin/session` | `user_roles` | `admin-auth.controller.ts:33` | `admin/auth/api.test.ts` | V |
| FN-007 | Email OTP request | `VerificationScreen` | — | `POST /auth/otp/request` | `otp_challenges` | `auth/token-lifecycle.service.ts:178-258` | `token-lifecycle.controller.spec` (4) | V |
| FN-008 | Email OTP verify + activation | `VerificationScreen` | — | `POST /auth/otp/verify` | `otp_challenges`,`users` | `token-lifecycle.service.ts:230-258` | `token-lifecycle.controller.spec` | V |
| FN-009 | Refresh-token rotation | `AuthController.validAccessToken` | — | `POST /auth/token/refresh` | `auth_sessions` | `token-lifecycle.service.ts:72-138` | `token-lifecycle.controller.spec`, `auth.integration-spec` | V |
| FN-010 | Replay detection (family revoke) | — | — | `POST /auth/token/refresh` | `auth_sessions`,`auth_audit_events` | `token-lifecycle.service.ts:80-94` | `token-lifecycle.controller.spec` | V |
| FN-011 | Logout (current / all) | `VerificationScreen` (back) | shell logout | `POST /auth/logout[-all]` | `auth_sessions` | `token-lifecycle.controller.ts:76,90` | `token-lifecycle.controller.spec` | V |
| FN-012 | Password reset request | — | — | `POST /auth/customer/password-reset/request` | `password_reset_tokens` | `auth.service.ts:307-391` | `auth.service.spec` | V |
| FN-013 | Password reset confirm | — | — | `POST /auth/customer/password-reset/confirm` | `password_reset_tokens`,`auth_sessions` | `auth.service.ts:350-391` | `auth.service.spec` | V |
| FN-014 | Login lockout (5 / 15 min) | — | — | *(inside login)* | `auth_credentials` | `auth.service.ts:262-280` | `auth.service.spec` | V |
| FN-015 | Customer profile read/update | `CustomerProfileScreen` | `/users/[userId]` | `GET|PATCH /users/me/profile` | `customer_profiles` | `users/customer-profile.controller.ts:12` | `customer-profile.controller.spec`, `customer-profile.integration-spec` | V |
| FN-016 | Saved addresses CRUD | `CustomerProfileScreen`, `AddEditAddressModalSheet` | — | `GET|POST|DELETE /users/me/addresses` | `customer_addresses` | `users/customer-addresses.controller.ts:23` | `customer-addresses.controller.spec` (12) | V |
| FN-017 | Authorization guard (deny-by-default) | — | — | *global* | — | `common/authorization/authorization.guard.ts:22-50` | `authorization.guard.spec` (5), `authorization.integration-spec` | V |
| FN-018 | Ownership proof interceptor | — | — | *global response interceptor* | — | `ownership-proof.interceptor.ts:36-60` | `ownership-proof.interceptor.spec` (3) | V |
| FN-019 | Audit trail (value-free events) | — | — | *all mutations* | `auth_audit_events`,`booking_events`,`complaint_audits` | `auth/auth-audit-event.entity.ts` | `customer-profile.integration-spec:111` | V |

## 2. Service catalog

| ID | Feature / workflow | Mobile | Admin | Backend endpoint | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FN-020 | Browse active categories | `ServiceDiscoveryScreen` | — | `GET /service-categories/active` | `service_categories` | `service_discovery_controller.dart:19` | `service-categories.controller.spec` (8) | V |
| FN-021 | Emergency categories | `ServiceDiscoveryScreen` banner | — | `GET /service-categories/emergency` | `service_categories` | `service-categories.controller.ts:45` | `service-categories.controller.spec` | V |
| FN-022 | Category by slug / id | `SubServiceCatalogScreen` | — | `GET /service-categories/slug/:slug`, `/:id` | `service_categories` | `service-categories.controller.ts:54-64` | `service-categories.controller.spec` | V |
| FN-023 | Sub-service catalog | `SubServiceCatalogScreen` | — | `GET /sub-services?categoryId=` | `sub_services` | `services/sub-services.controller.ts:41` | ⚠️ **none** | U |
| FN-024 | Cart + quantity steppers | `SubServiceCatalogScreen`, `_CartSummarySheet` | — | — (client) | — | `sub_service_item.dart:114` | `sub_service_catalog_screen_test.dart` | V |
| FN-025 | Category create/update/delete | — | `/services` | `POST|PUT|DELETE /admin/service-categories` | `service_categories` | `admin-management.controller.ts:73-90` | `service-categories.service.spec` (21) | V |
| FN-026 | Category pricing (admin-published) | `ServiceCard.priceFrom` | `/services` | same as FN-025 | `service_categories.price_amount/currency` | `service-category.entity.ts:27-36` | `service-categories.pricing.dto.spec` (5) | V |
| FN-027 | Price-on-request (honest abstention) | `ServiceRequestScreen`, `FixPriceBreakdownCard` | `/services` (clearPricing) | `pricing: null` | `service_categories` | `mobile/.../fix_price_breakdown_card.dart:204` | `sub_service_catalog_screen_test.dart` | V |

## 3. Provider onboarding

| ID | Feature / workflow | Mobile | Admin | Backend endpoint | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FN-028 | Read own application | `ProviderOnboardingScreen` | `/providers/[id]` | `GET /provider-applications/me` | `provider_applications` | `provider-application.controller.ts:27` | ⚠️ controller untested | U |
| FN-029 | Submit application | `ProviderOnboardingScreen` | — | `POST /provider-applications/me/submit` | `provider_applications` | `provider-application.controller.ts:47` | ⚠️ none | U |
| FN-030 | Provider profile | `ProviderOnboardingScreen` | `/providers` | `GET|PUT /provider-profile/me` | `provider_profiles` | `provider-profile.controller.ts:19-32` | `provider-profile.service.spec` (7) | V |
| FN-031 | Live location publish (throttled) | `ProviderController` | — | `PUT /provider-profile/me/location` | `provider_profiles.base_*` | `provider-profile.controller.ts:63-68` | `provider-profile.service.spec` | V |
| FN-032 | Coverage check | onboarding wizard | — | `PUT /provider-profile/me/coverage-check` | `provider_profiles` | `provider-profile.controller.ts:82` | `provider-profile.service.spec` | V |
| FN-033 | Skills CRUD | onboarding dropdown | `/providers` | `GET|POST|PUT|DELETE /provider-skills` | `provider_skills` | `provider-skills.controller.ts:39-172` | `provider-skills.controller.spec` (14), `.service.spec` (19) | V |
| FN-034 | Skill verification | — | `/providers/[id]` | `PUT /provider-skills/:id/verify` | `provider_skills.is_verified` | `provider-skills.controller.ts:157` | `provider-skills.service.spec` | V |
| FN-035 | Weekly schedule + exceptions | `FixProviderWorkingHoursSheet` | — | `PUT /provider-availability/me/schedule` | `provider_availability` | `availability/provider-availability.controller.ts:34` | `provider-availability.service.spec` (5) | V |
| FN-036 | Online/busy/offline status | `ProviderHomeScreen` switch | — | `PUT /provider-availability/me/status` | `provider_availability` | `provider-availability.controller.ts:53` | `provider-availability.service.spec` | V |
| FN-037 | Capacity enforcement | — | — | *(inside accept)* | `provider_availability` | `availability/provider-capacity.service.ts:55-63` | `provider-capacity.service.spec` (8) | V |
| FN-038 | KYC document upload | onboarding camera/file | `/providers/[id]/documents` | `POST /provider-documents/:type` | `provider_documents`,`provider_document_audit_events` | `documents/provider-document.controller.ts:52` | `provider-document.service.spec` (10) | V |
| FN-039 | Document download | — | document proxy route | `GET /provider-documents/:id` | `provider_documents` | `provider-document.controller.ts:75` | `provider-document.service.spec` | V |
| FN-040 | Document delete (tombstone) | — | — | `DELETE /provider-documents/:id` | `provider_documents` | `provider-document.controller.ts:99` | `provider-document.service.spec` | V |
| FN-041 | Object storage adapter | — | — | — | — | `storage/s3-private-object-storage.ts` | ⚠️ **none** | U |
| FN-042 | ClamAV malware scan | — | — | — | — | `storage/clamav-malware-scanner.ts:31-63` | ⚠️ **none** | U/B |
| FN-043 | Reviewer claim | — | `/providers/[id]` claim form | `POST /admin/provider-applications/:id/claim` | `provider_applications` | `admin-management.controller.ts:146` | `provider-verification.service.spec` (7) | V |
| FN-044 | Reviewer decision | — | `/providers/[id]` decision form | `POST .../:id/decision` | `provider_applications`,`provider_verification_events` | `admin-management.controller.ts:160` | `provider-verification.service.spec` | V |
| FN-045 | Approval activates account + grants role | — | — | *(inside decision)* | `users`,`user_roles` | `verification/provider-verification.service.ts` | `provider-verification.service.spec` | V |

## 4. Booking lifecycle

| ID | Feature / workflow | Mobile | Admin | Backend endpoint | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FN-046 | Create booking (idempotent) | `ServiceRequestScreen` | — | `POST /bookings` | `bookings`,`booking_line_items` | `bookings.service.ts:236-345` | `bookings.service.spec` (33), `booking-lifecycle.integration-spec:132` | V |
| FN-047 | Price resolution + GST | `ServiceRequestScreen`, `FixPriceBreakdownCard` | — | *(inside create)* | `bookings.total_amount_minor` | `domain/booking-items.ts:24-55` | `booking-items.spec` (2) | V |
| FN-048 | Request dispatch fan-out | — | — | *(outbox)* | `outbox_messages` | `bookings.service.ts:352-381` | ⚠️ dispatch handlers untested | U |
| FN-049 | Provider eligibility matching | `ProviderJobsScreen` | `/bookings` | *(in-process)* | `provider_skills`,`provider_availability`,`provider_profiles` | `matching/matching.service.ts` | `matching.service.spec` (16), `booking-lifecycle.integration-spec:170` | V |
| FN-050 | Provider accept | `ProviderIncomingRequestScreen`, `ProviderHomeScreen` | `/bookings` | `POST /bookings/:id/accept` | `bookings`,`booking_events` | `bookings.service.ts:750-839` | `bookings.service.spec`, `booking-lifecycle.integration-spec:199` | V |
| FN-051 | Status transitions (provider) | cockpit "Start journey"/"Complete" | `/bookings` | `PATCH /bookings/:id/status` | `bookings`,`booking_events` | `bookings.service.ts:847-849,1492-1572` | `bookings.service.spec`, integration `:225` | V |
| FN-052 | Service-start OTP issue | `BookingTrackingScreen` | — | `POST /bookings/:id/service-start-otp` | — (derived) | `bookings.service.ts:1588-1598` | `bookings.service.spec` | V |
| FN-053 | Service-start OTP verify | `FixOtpInputSheet`, `ProviderNavigationMapScreen` | — | `POST /bookings/:id/start-service` | `bookings` | `bookings.service.ts:1254-1290` | `booking-lifecycle.integration-spec:26-31` (independent HMAC reimpl.) | V |
| FN-054 | Item adjustment | `ServiceAdjustmentSheet` | — | `PATCH /bookings/:id/items` | `bookings.items` | `bookings.service.ts:1182-1201` | `bookings.service.spec` | V |
| FN-055 | Line-item editing (extra charges) | `_handleAddExtraCharge` | — | `PUT /bookings/:id/line-items` | `booking_line_items` | `bookings.service.ts:900-924` | `bookings.service.spec` | V |
| FN-056 | Cancel (customer/provider) | `CancellationDialog`, `_CancelButton` | `POST /admin/bookings/:id/cancel` | `POST /bookings/:id/cancel` | `bookings`,`booking_events` | `bookings.service.ts:119-131,230-258` | `bookings.service.spec`, integration `:295` | V |
| FN-057 | Reschedule | `FixRescheduleSheet` | — | `POST /bookings/:id/reschedule` | `bookings.scheduled_at` | `bookings.service.ts:1110-1128` | `bookings.service.spec` | V |
| FN-058 | History (keyset pagination) | `CustomerBookingsScreen` | — | `GET /bookings` | `bookings` | `bookings.service.ts:1303-1331,1714-1735` | `bookings.controller.spec` (19), integration `:295` | V |
| FN-059 | Available requests | `ProviderJobsScreen` | — | `GET /bookings/available` | `bookings` | `bookings.service.ts:308` | `bookings.controller.spec` | V |
| FN-060 | Booking detail (ownership + redaction) | `BookingDetailScreen` | `/bookings/[bookingId]` | `GET /bookings/:id` | `bookings` | `bookings.service.ts:1365-1382` | integration `:128` | V |
| FN-061 | Unmatched-request expiry | — | — | *(outbox sweeper)* | `bookings` | `booking-dispatch.handlers.ts:145-202` | ⚠️ **none** | U |
| FN-062 | Recurring schedules | `_SchedulesSection` | — | `POST|GET /bookings/schedules`, `PATCH .../status`, `POST .../confirm` | `recurring_schedules` | `schedules.controller.ts:16` | `schedules.service.spec` (12) | V |
| FN-063 | Scheduled booking reminders | — (push only) | — | *(interval scanner)* | `bookings`,`notification_deliveries` | `notifications/domain/booking-reminder.service.ts` | `booking-reminder.service.spec` (5) | V |
| FN-064 | Re-service booking (guarantee) | — | `/guarantees/[id]` | `POST /guarantees/claims/:id/re-service` | `bookings.parent_booking_id`,`bookings.is_guarantee_claim` | `guarantees.service.ts` | integration `:341,400,427,450` | V |

## 5. Realtime, tracking, chat, calls

| ID | Feature / workflow | Mobile | Admin | Backend | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FN-065 | WebSocket auth handshake | `RealtimeClient` | — | gateway `authenticate` | `auth_sessions` | `realtime.gateway.ts:278-327` | `realtime.gateway.spec` (5) | V |
| FN-066 | Connection/registration limits | — | — | gateway registry | — | `realtime-connection-registry.service.ts` | `.spec` (4) | V |
| FN-067 | Session revalidation | `revalidateOnResume()` | — | gateway `:577-640` | `auth_sessions` | `realtime.gateway.ts:577` | `realtime-session-revalidation.spec` (9) | V |
| FN-068 | Booking projection stream | `BookingTrackingController` | — | `booking.projection-updated.v1` | `bookings` | `realtime/booking-projection.service.ts:93` | ⚠️ **none** | U |
| FN-069 | Live location updates | `ProviderController`, `ProviderLiveMap` | — | `location-update` | — (in-memory) | `realtime.gateway.ts:237` | `realtime.journey.spec` (4) | V |
| FN-070 | ETA / route adapter | `ProviderNavigationMapScreen` | `/bookings` | `EtaAdapter`/`RouteAdapter` | — | `realtime/eta-adapter.ts`, `route-adapter.ts` | `eta-adapter.spec` (2), `route-adapter.spec` (10) | V/B |
| FN-071 | Live tracking screen | `BookingTrackingScreen` | — | `GET /bookings/:id` | `bookings` | `booking_tracking_source.dart` | tracking widget tests | V |
| FN-072 | In-booking chat | `BookingChatScreen` | — | `GET|POST /bookings/:id/messages` | `booking_messages` | `booking-messages.controller.ts:33` | `.controller.spec` (2), `.service.spec` (13) | V |
| FN-073 | Chat realtime + 3 s poll fallback | `ChatController` | — | `chat.message-received.v1` | `booking_messages` | `chat_controller.dart:46` | chat tests | V |
| FN-074 | In-app calling | `Call` buttons | — | `POST /bookings/:id/calls/*` | `booking_calls` | `booking-calls.controller.ts:20` | `.controller.spec` (6), `.service.spec` (15) | V |
| FN-075 | **Calling UI wiring** | cockpit/tracking `Call` | — | — | — | `features/call/*` | ⚠️ **repo never instantiated** | **S** |

## 6. Payments & guarantees

| ID | Feature / workflow | Mobile | Admin | Backend endpoint | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FN-076 | Create payment order | `LocalPaymentRepository` (dev) | — | `POST /payments/orders` | `payment_orders` | `payments.service.ts:60-190` | `payments.service.spec` (33) | V |
| FN-077 | Order lookup by booking | `InvoiceRepository` | — | `GET /payments/orders/booking/:id` | `payment_orders` | `payments.service.ts:196-213` | `payments.service.spec` | V |
| FN-078 | Checkout signature verify | `LocalPaymentRepository` | — | `POST /payments/orders/verify` | `payment_orders` | `payments.service.ts:194-213` | `payment-gateway.spec` (8) | V |
| FN-079 | Webhook HMAC + replay | — | — | `POST /payments/webhook` | `payment_events` | `payments.service.ts:220-293` | `payments.service.spec` | V |
| FN-080 | Invoice read | `InvoiceScreen` | — | `GET /payments/invoices/:orderId` | `invoices` | `payments.controller.ts:56` | ⚠️ controller untested | U |
| FN-081 | Admin refund | — | `/guarantees`, `/support` | `POST /admin/payments/orders/:id/refunds` | `refunds` | `payments-admin.controller.ts:24` | `payments.service.spec` | V |
| FN-082 | Provider earnings ledger | `ProviderEarningsScreen` | — | `GET /providers/me/earnings` | `payment_orders`,`refunds` | `provider-earnings.controller.ts:16` | ⚠️ untested | U |
| FN-083 | Booking payment status | cockpit | — | `GET /providers/me/bookings/:id/payment-status` | `payment_orders` | `provider-earnings.controller.ts:27` | ⚠️ untested | U |
| FN-084 | Interactive checkout sheet | `InvoiceScreen` | — | — (client-only) | — | `fix_payment_checkout_sheet.dart:15` | `invoice_screen_test.dart` | **S** (dev-gated; simulates success) |
| FN-085 | PDF invoice + share | `FixShareInvoiceSheet` | — | — | — | `fix_pdf_invoice_builder.dart` | `pdf_tax_invoice_test.dart` | V |
| FN-086 | **Invoice entity data** | `FixPdfInvoiceBuilder` | — | — | — | `fix_pdf_invoice_builder.dart:13-25` | — | **S** (hardcoded GSTIN, two conflicting cities) |
| FN-087 | Guarantee claim (customer) | `SubmitClaimScreen`, booking detail "Claim" | — | `POST /guarantees/claims` | `guarantee_claims` | `guarantees.controller.ts:35` | `guarantees.controller.spec` (8) | V |
| FN-088 | Guarantee claim admin queue | — | `/guarantees` | `GET /guarantees/claims` | `guarantee_claims` | `guarantees.controller.ts:60` | `guarantees.service.spec` (7) | V |
| FN-089 | Guarantee status update | — | `/guarantees/[id]` | `PATCH .../claims/:id/status` | `guarantee_claims` | `guarantees.controller.ts:75` | `guarantees.controller.spec` | V |

## 7. Emergency

| ID | Feature / workflow | Mobile | Admin | Backend endpoint | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FN-090 | Emergency request (hold-to-confirm) | `EmergencyConfirmScreen` | `/bookings` | `POST /emergency/requests` | `bookings`,`emergency_dispatches` | `emergency/emergency.controller.ts:37` | `emergency.service.spec` (23) | V |
| FN-091 | Wave escalation | dispatched view | — | `GET /emergency/requests/:bookingId` | `emergency_dispatches.wave_history` | `emergency-wave.handlers.ts` | `emergency.service.spec` | V |
| FN-092 | One-open-emergency-per-customer | — | — | *(partial unique)* | `UQ_emergency_dispatches_active_customer` | `1789750100000:100` | `emergency.service.spec` | V |
| FN-093 | Dispatch monitor | — | `GET /admin/emergency/dispatches` | `admin/emergency/dispatches` | `emergency_dispatches` | `emergency.controller.ts:70` | ⚠️ controller untested | U |

## 8. Ratings & reviews

| ID | Feature / workflow | Mobile | Admin | Backend endpoint | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FN-094 | Submit review | `BookingReviewPanel` | — | `POST /bookings/:id/review` | `booking_reviews` | `ratings.controller.ts:36` | `ratings.service.spec` (4) | V |
| FN-095 | Read review | `BookingDetailScreen` | — | `GET /bookings/:id/review` | `booking_reviews` | `ratings.controller.ts:56` | `ratings.service.spec` | V |
| FN-096 | Review photo upload | `BookingReviewPanel` | — | `POST /bookings/:id/review/photos` | `review_photos` | `ratings.controller.ts:81` | `review-photos.service.spec` (10) | V |
| FN-097 | Review moderation | — | ⚠️ no page | `PATCH /admin/reviews/:id/moderation` | `booking_reviews`,`review_moderation_events` | `ratings-admin.controller.ts:22` | ⚠️ **none** | U |
| FN-098 | Photo moderation | — | ⚠️ no page | `PATCH /admin/reviews/photos/:photoId/moderation` | `review_photos`,`review_photo_moderation_events` | `ratings-admin.controller.ts:42` | ⚠️ **none + shadowed route (GAP-14)** | **P** |

## 9. Trust, support, notifications

| ID | Feature / workflow | Mobile | Admin | Backend endpoint | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FN-099 | Trust signal rules | — | `/trust` | *(engine)* | `trust_signals` | `trust/trust.service.ts` | `trust.service.spec` (12), `price-fraud-eval-v1.spec` (9) | V |
| FN-100 | Trust signal queue | — | `/trust` | `GET /admin/trust/signals` | `trust_signals` | `trust-admin.controller.ts:26` | ⚠️ controller untested | U |
| FN-101 | Signal review/dismiss | — | `/trust` forms | `PATCH /admin/trust/signals/:id` | `trust_signals` | `trust-admin.controller.ts:31` | `trust/actions.test.ts` (3) | V |
| FN-102 | Provider accept-time signal | `ProviderHomeScreen` | `/trust` | `GET /trust/my-accept-time` | `trust_signals` | `trust.controller.ts:15` | `trust.service.spec` | V |
| FN-103 | Create complaint | `SubmitComplaintScreen` | `/support` | `POST /support/complaints` | `complaints` | `complaints.controller.ts:26` | `complaints.controller.spec` (5) | V |
| FN-104 | Complaint list/detail | `ComplaintListScreen` | `/support`, `/support/[id]` | `GET /support/complaints[/:id]` | `complaints`,`complaint_evidence` | `complaints.controller.ts:44,90` | `complaints.service.spec` (25) | V |
| FN-105 | Complaint evidence (trusted URL) | `_openProofModal` | `/support/[id]` | `POST /support/complaints/:id/evidence` | `complaint_evidence` | `complaints.controller.ts:63` | `trusted-evidence-url.spec` (13) | V |
| FN-106 | Complaint adjudication | — | `/support/[id]` form | `PATCH /admin/complaints/:id/status` | `complaints`,`complaint_audits` | `admin-management.controller.ts:52` | `complaints.service.spec` | V |
| FN-107 | Complaint list (admin) | — | `/support` | `GET /admin/complaints` (**unpaginated**) | `complaints` | `admin-management.controller.ts:211` | ⚠️ none | U |
| FN-108 | Notification inbox | `NotificationCenterScreen` | — | `GET /users/:userId/notifications` | `in_app_notifications` | `notifications/domain/inbox.controller.ts:21` | `inbox.controller.spec` (7) | V |
| FN-109 | Mark notification read | notification card | — | `PATCH .../notifications/:id/read` | `in_app_notifications` | `domain/inbox.controller.ts:64` | `inbox.controller.spec` | V |
| FN-110 | **Clear-all notifications** | `_confirmClearAll` | — | ⚠️ **no server delete endpoint** | — (client-only set) | `notification_repository.dart:90-96` | ⚠️ none | **S** |
| FN-111 | Push device registration | `PushSettingsCard`, `push_enrollment.dart` | — | `PUT /notifications/push/devices` | `push_device_tokens` | `push/push.controller.ts:20` | `push.controller.spec` (4) | V/B |
| FN-112 | Push delivery (FCM) | foreground banner | — | *(worker)* | `notification_deliveries` | `push/push-delivery.ts` | `push-delivery.spec` (4) | V/B |
| FN-113 | Domain notifications | — | — | *(writer)* | `in_app_notifications`,`notification_deliveries` | `domain/domain-notification.service.ts` | `.spec` (7) | V |
| FN-114 | **Public inbox stub** | — | — | `GET /notifications/inbox` | — | `notifications/inbox.controller.ts:6` | ⚠️ **not registered in any module** | **S** (GAP-13) |

## 10. AI (advisory-only, ADR-0014)

| ID | Feature / workflow | Mobile | Admin | Backend endpoint | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FN-115 | Issue → service recommendation | `ProblemDiagnosisScreen` | — | `POST /ai/service-recommendation` | `service_categories` (grounding) | `ai/issue-recommendation.service.ts` | `.service.spec` (4), `.controller.spec` (1) | V |
| FN-116 | Advisory price estimate | `ServiceRequestScreen` | — | `GET /ai/price-estimate` | `service_categories`,`payment_orders` | `ai/pricing/price-estimate.service.ts` | `.spec` (4), `price-fraud-eval-v1.spec` (9) | V |
| FN-117 | Image problem classification | `ProblemDiagnosisScreen` | — | `POST /ai/problem-analysis/image` | — | `problem-classification.service.ts` | `.service.spec` (18), eval (7) | V |
| FN-118 | Voice problem classification | `ProblemDiagnosisScreen` | — | `POST /ai/problem-analysis/voice` | — | `problem-classification.service.ts` | `.service.spec` | V |
| FN-119 | Combined image+voice | — | — | `POST /ai/problem-analysis/combined` | — | `problem-classification.controller.ts:96` | `.controller.spec` (2) | V |
| FN-120 | Media policy (mime/magic bytes) | — | — | — | — | `ai/policy/ai-media-policy.ts` | `.spec` (5) | V |
| FN-121 | Image metadata stripping | — | — | — | — | `ai-media-policy.ts:249-350` | `.spec` | V |
| FN-122 | PII redaction in prompts | — | — | — | — | `ai/policy/ai-request-sanitizer.ts` | — | U |
| FN-123 | Deterministic AI provider | — | — | — | — | `ai/providers/deterministic-ai.provider.ts` | ⚠️ **none** | U |
| FN-124 | HuggingFace provider | — | — | — | — | `ai/providers/huggingface-ai.provider.ts` | ⚠️ **none** | U/B |
| FN-125 | Concurrency limiter | — | — | — | — | `ai/ai.service.ts:111-118` | `concurrency-limiter.spec` (7) | V |
| FN-126 | **AI diagnostic screen** | `AiDiagnosticScreen` | — | — | — | `features/ai/ai_diagnostic_screen.dart` | ⚠️ **dead file** | **S** |
| FN-127 | **AI recommendation screen** | `AiRecommendationScreen` | — | — | — | `features/ai/ai_recommendation_screen.dart` | ⚠️ **dead file** | **S** |

## 11. Admin operations

| ID | Feature / workflow | Admin route | Backend endpoint | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FN-128 | Admin session cookie | `/login` | `GET /auth/admin/session` | `auth_sessions` | `admin/src/auth/session.ts:6-57` | `session.test.ts` (2), `api.test.ts` (2) | V |
| FN-129 | Operations dashboard | `/` | `GET /admin/analytics` | aggregates | `admin/src/app/page.tsx:15` | `admin-analytics.service.spec` (5) | V |
| FN-130 | Full analytics | `/analytics` (**orphan**) | `GET /admin/analytics` | aggregates | `admin/src/app/analytics/page.tsx:8` | ⚠️ none | U |
| FN-131 | Booking list + filters | `/bookings` | `GET /admin/bookings` | `bookings` | `admin/src/app/bookings/page.tsx:17` | `admin-operations.spec.ts:28` (e2e) | V |
| FN-132 | Booking dossier + cancel | `/bookings/[bookingId]` | `GET .../:id`, `POST .../cancel` | `bookings`,`booking_events` | `bookings/[bookingId]/page.tsx:15` | ⚠️ none | U |
| FN-133 | Provider KYC queue | `/providers` | `GET /admin/provider-applications` | `provider_applications` | `providers/page.tsx:12` | `providers/page.test.tsx` (1) | V |
| FN-134 | Provider KYC dossier | `/providers/[applicationId]` | 4 calls | `provider_applications`,`provider_documents` | `providers/[applicationId]/page.tsx:20` | ⚠️ none | U |
| FN-135 | Document proxy route | `/providers/[aId]/documents/[docId]` | `GET .../documents/:d` | `provider_documents` | `.../documents/[documentId]/route.ts:4` | ⚠️ none | U |
| FN-136 | Complaint queue | `/support` | `GET /admin/complaints` | `complaints` | `support/page.tsx:12` | `support/page.test.tsx` (2), e2e `:63,105` | V |
| FN-137 | Case dossier + adjudication | `/support/[complaintId]` | 4 calls | `complaints`,`complaint_audits` | `support/[complaintId]/page.tsx` | `page.test.tsx` (1) | V |
| FN-138 | Trust moderation queue | `/trust` | `GET /admin/trust/signals` | `trust_signals` | `trust/page.tsx:32` | `trust/page.test.tsx` (3) | V |
| FN-139 | **Trust page access control** | `/trust` | — | — | `trust/page.tsx:37` | ⚠️ `test.fixme` (e2e:148) | **P** (GAP-05) |
| FN-140 | Category + pricing admin | `/services` | CRUD `/admin/service-categories` | `service_categories` | `services/page.tsx:11` | `design-tokens.test.ts` + e2e `:158` | V |
| FN-141 | Guarantee queue + detail | `/guarantees`, `/guarantees/[id]` | `GET|PATCH /guarantees/claims` | `guarantee_claims` | `guarantees/page.tsx`, `[id]/page.tsx` | ⚠️ none | U |
| FN-142 | User registry | `/users` (**orphan**) | `GET /admin/users` | `users` | `users/page.tsx:18` | ⚠️ none | U |
| FN-143 | Account detail | `/users/[userId]` | `GET /admin/users/:id` | `users`,`user_roles` | `users/[userId]/page.tsx` | ⚠️ none | U |
| FN-144 | Cross-entity search | `/search` (header form) | 4 calls sequential | multiple | `search/page.tsx:23` | ⚠️ none | U |
| FN-145 | Complaint submitter/target detail | `/support/[complaintId]` | `GET /admin/users/:id` | `users` | `operations/types.ts:16` | ⚠️ none | **P** (GAP-17) |
| FN-146 | Admin error boundary | all | — | — | `app/error.tsx:29` | `design-tokens.test.ts:293` | V |
| FN-147 | Global error boundary | all | — | — | `app/global-error.tsx:17` | ⚠️ none | V |
| FN-148 | Root loading skeleton | all | — | — | `app/loading.tsx:55` | ⚠️ none | V |
| FN-149 | 404 page | all | — | — | `app/not-found.tsx:16` | ⚠️ none | V |

## 12. Operations & platform

| ID | Feature | Where | Backend | Tables | Key source | Tests | S |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FN-150 | Transactional outbox | — | — | `outbox_messages` | `outbox/outbox.service.ts` | ⚠️ **none** | U |
| FN-151 | Outbox handlers (dispatch/expiry/reminder/wave) | — | — | `outbox_messages` | `bookings/booking-dispatch.handlers.ts`, `emergency-wave.handlers.ts` | ⚠️ none | U |
| FN-152 | Redis cache | — | — | — | `cache/cache.module.ts` | `cache.module.spec` (8) | V |
| FN-153 | Redis availability watch | — | `/health/readiness` | — | `cache.module.ts:118-163` | `cache.module.spec` | V |
| FN-154 | Liveness / readiness | — | `GET /health/*` | — | `health/health.controller.ts:25` | `health.controller.spec` (9) | V |
| FN-155 | Health dashboard (HTML) | — | `GET /health/dashboard` | — | `health.controller.ts:114` | `health-dashboard.spec` (11) | V |
| FN-156 | System health service | — | — | — | `health/system-health.service.ts` | ⚠️ **none** | U |
| FN-157 | Prometheus metrics | — | `GET /health/metrics` | — | `observability/metrics.controller.ts:22` | `metrics.integration-spec` (8) | V |
| FN-158 | Error reporting (Sentry-compatible) | — | — | — | `observability/error-reporter.ts` | `error-reporter.spec` (10) | V |
| FN-159 | Structured logging + redaction | — | — | — | `logging/logger.module.ts` | `request-correlation.spec` (9) | V |
| FN-160 | Correlation IDs | — | — | — | `common/middleware/request-correlation.middleware.ts` | `request-correlation.spec` | V |
| FN-161 | Security headers middleware | — | — | — | `common/middleware/security-headers.middleware.ts` | `.spec` (7) | V |
| FN-162 | Global exception filter | — | — | — | `common/filters/all-exceptions.filter.ts` | `.spec` (10) | V |
| FN-163 | Configurable throttle | — | — | — | `common/throttling/configurable-throttle.guard.ts` | `.spec` (8) | V |
| FN-164 | Graceful shutdown | — | — | — | `common/graceful-shutdown.ts` | `.spec` (11) | V |
| FN-165 | Bounded concurrency runner | — | — | — | `common/run-bounded.ts` | `.spec` (6) | V |
| FN-166 | Env validation + prod boot guards | — | — | — | `config/env.validation.ts` | `.spec` (26), `env.production-boot.spec` (6) | V |
| FN-167 | OpenAPI document | — | `/api/docs` | — | `openapi/openapi.document.ts` | `openapi.integration-spec` (10) | V |
| FN-168 | Reverse proxy (dev) | port 8080 | — | — | `scripts/proxy.ts` | ⚠️ none | U |
| FN-169 | Dev orchestrator | `bun dev` | — | — | `scripts/dev.ts` | ⚠️ none | U |
| FN-170 | Secret scanner | CI gate | — | — | `scripts/scan-secrets.mjs` | `--self-test` ✅ | **P** (GAP-01) |
| FN-171 | Schema verification gates | CI | — | — | `backend/scripts/verify-schema.ts`, `verify-fresh-schema.ts` | ✅ 46/46 | V (P for behaviour) |
| FN-172 | DTO class gate | CI | — | — | `backend/scripts/check-body-dto-classes.ts` | ✅ | P (GAP-16) |
| FN-173 | Env declaration gate | CI | — | — | `backend/scripts/check-env-declarations.ts` | ✅ | V |
| FN-174 | Deploy config gate | CI | — | — | `backend/scripts/verify-deploy-env.ts` | ✅ | V |
| FN-175 | Catalog seed | deploy (`render.yaml`) | — | `sub_services` | `backend/seed.js` | ⚠️ none | **P** (GAP-19) |

---

## Appendix A — Database entity ledger

Every entity with its table, key columns, relations, and integrity controls. "Conc." = concurrency control; "Del." = deletion behaviour.

### Identity

| Table | Key columns | Relations | Unique / checks | Conc. | Del. |
| --- | --- | --- | --- | --- | --- |
| `users` | `status` enum `account_status`, `phone`, `status_reason` | — | status enum | — | referenced by `RESTRICT` FKs |
| `user_identities` | `provider`, `subject`, `verified_at` | → `users` CASCADE | UNIQUE(`provider`,`subject`) | — | CASCADE |
| `roles` | `code`, `description` | — | UNIQUE(`code`) | — | RESTRICT |
| `user_roles` | `user_id`,`role_id`,`assigned_by`,`expires_at` | → `users` CASCADE, → `roles` RESTRICT | UNIQUE(`user_id`,`role_id`) | — | CASCADE |
| `auth_credentials` | `password_hash`,`failed_login_count`,`locked_until` | → `user_identities` CASCADE (1:1) | `identity_id` unique | conditional UPDATE | CASCADE |
| `password_reset_tokens` | `token_hash`,`expires_at`,`consumed_at` | — (FK CASCADE in DB) | `token_hash` unique, IDX on identity | single-use conditional UPDATE | CASCADE |
| `customer_profiles` | `user_id` PK, `display_name` | → `users` CASCADE (1:1) | PK | — | CASCADE |
| `customer_addresses` | `street`,`city`,`state`,`zip`,`lat`,`lng`,`is_default` | → `customer_profiles` CASCADE | ⚠️ **no unique on single default** | — | CASCADE |

### Session

| Table | Key columns | Notes |
| --- | --- | --- |
| `auth_sessions` | `token_family_id`,`refresh_token_hash`,`revoked_at`,`replaced_by_session_id` | `char(64)` unique; `pessimistic_write` on refresh |
| `otp_challenges` | `code_hash`,`expires_at`,`resend_after`,`attempts_remaining` | HMAC-hashed |
| `auth_audit_events` | `user_id` (nullable),`event_type`,`outcome` | ⚠️ FK **CASCADE** — user deletion erases the audit trail |

### Catalog

| Table | Key columns | Notes |
| --- | --- | --- |
| `service_categories` | `name`,`slug`,`price_amount`,`price_currency`,`is_active`,`is_emergency` | UNIQUE name+slug; **CHECK pricing pair** |
| `sub_services` | `category_id`,`price_minor`,`currency`,`estimated_duration_minutes`,`badge` | → categories CASCADE |

### Provider

| Table | Key columns | Notes |
| --- | --- | --- |
| `provider_applications` | `user_id`,`status` enum,`assigned_reviewer_user_id`,`version` | UNIQUE user_id; ⚠️ `version` is **not** `@VersionColumn` |
| `provider_profiles` | `user_id`,`service_radius_km`,`base_*`,`base_location_updated_at` | UNIQUE user_id; staleness index |
| `provider_skills` | `user_id`,`service_category_id`,`is_verified`,`hourly_rate_cents` | UNIQUE(user,category) — **unnamed** |
| `provider_availability` | `user_id`,`time_zone`,`weekly_rules` jsonb,`exceptions` jsonb,`status`,`version` | 2 CHECKs (migration-only); ⚠️ `version` not `@VersionColumn`; `pessimistic_write` on accept |
| `provider_documents` | `document_type`,`object_key`,`sha256`,`status`,`retention_until`,`deleted_at` | UNIQUE `object_key`; `deleted_at` is a **plain column**, not `@DeleteDateColumn` |
| `provider_document_audit_events` | `document_id`,`actor_user_id`,`action`,`outcome` | append-only |
| `provider_verification_events` | `application_id`,`actor_user_id`,`from/to_status`,`application_version` | append-only |

### Booking

| Table | Key columns | Notes |
| --- | --- | --- |
| `bookings` | `customer_id`,`provider_id`,`status` enum,`items` jsonb,`total_amount_minor`,`location_lat/lng`,7 lifecycle timestamps,`is_guarantee_claim`,`parent_booking_id`,`cancellation_reason` | UNIQUE(`customer_id`,`idempotency_key`); `@VersionColumn`; `@DeleteDateColumn`; 5 CHECKs (migration-only); **line items eager** |
| `booking_events` | `booking_id`,`actor_user_id` (nullable),`from/to_status`,`booking_version` | **immutability trigger**; FK actor RESTRICT |
| `booking_line_items` | `booking_id`,`sub_service_id`,`quantity`,`price_minor` | → bookings CASCADE; ⚠️ no unique on (booking, sub_service) |
| `booking_messages` | `sender_user_id`,`sender_role`,`client_message_id`,`message_text`,`read_at` | ⚠️ `client_message_id` **not unique** → retry duplicates |
| `booking_calls` | `caller_user_id`,`callee_user_id`,`status`,`connected_at`,`duration_seconds` | ⚠️ no CHECK on status |
| `recurring_schedules` | `customer_id`,`cadence`,`status`,`next_occurrence_at` | ⚠️ **no FKs at all** — `customer_id` is an orphan column |
| `emergency_dispatches` | `booking_id` PK,`customer_id`,`current_wave`,`wave_history` jsonb | `@VersionColumn`; ⚠️ partial-unique index exists in DB but **not on the entity** |

### Payments

| Table | Key columns | Notes |
| --- | --- | --- |
| `payment_orders` | `booking_id`,`amount_minor`,`currency`,`status`,`gateway_order_id`,`receipt` | CHECK status; 2 unique idx (gateway_order, receipt); **no FKs** |
| `payment_events` | `order_id`,`event_type`,`payload_digest`,`actor` | UNIQUE(order,event,digest) = replay guard; ⚠️ **no FK** |
| `refunds` | `payment_order_id`,`request_key`,`amount_minor`,`status` | UNIQUE(order,request_key); CHECK status; **no FKs** |
| `invoices` | `payment_order_id`,`invoice_number`,`subtotal/tax/discount` | ⚠️ the one-invoice-per-order guarantee lives **only in the migration**; sequential number has no backing sequence |

### Ratings / Trust / Support / Notifications / Ops

| Table | Key columns | Notes |
| --- | --- | --- |
| `booking_reviews` | `booking_id`,`rating`,`review_text`,`moderation_status` enum | UNIQUE(booking_id); CHECK 1–5; `@VersionColumn` |
| `review_photos` | `review_id`,`object_key`,`status`,`sha256` | ⚠️ **no FK** to reviews; entity `varchar(512)` vs DB `varchar(16)` drift |
| `review_moderation_events` | `review_id`,`actor_user_id`,`from/to_status` | FKs RESTRICT |
| `review_photo_moderation_events` | `photo_id`,`actor_user_id` | ⚠️ **no FKs at all** |
| `trust_signals` | `subject_type`,`subject_id`,`rule_code`,`window_start`,`severity`,`status`,`appeal*` | UNIQUE(subject,rule,window); `@VersionColumn`; `subject_id` polymorphic |
| `guarantee_claims` | `booking_id`,`customer_id`,`status` enum,`evidence_urls` **simple-array** | ⚠️ **no FKs, no indexes, no unique**; simple-array corrupts URLs containing commas |
| `complaints` | `booking_id`,`submitter_id`,`target_role` enum,`status` enum,`appeal*` | `@VersionColumn`; ⚠️ state machine lives **only in app code** — direct SQL bypasses it |
| `complaint_evidence` | `complaint_id`,`uploaded_by`,`file_url` | → complaints CASCADE; ⚠️ **stores a raw URL** (unlike other uploads which store opaque keys); only singular table name |
| `complaint_audits` | `complaint_id`,`actor_id`,`previous/new_status` | ⚠️ **no immutability trigger** (unlike `booking_events`) |
| `in_app_notifications` | `user_id`,`title`,`body`,`kind`,`read_at` | ⚠️ no indexes, no FKs, no retention |
| `notification_deliveries` | `user_id`,`kind`,`dedupe_key`,`status` | UNIQUE(dedupe_key,user_id); no FK |
| `push_device_tokens` | `user_id`,`platform` enum,`token` | `token` unique (server-side only); → users CASCADE |
| `outbox_messages` | `kind`,`dedupe_key`,`payload` jsonb,`available_at`,`attempts`,`claimed_at` | UNIQUE `dedupe_key`; IDX(`available_at`,`id`); CHECK kind; **no FKs** |

## Appendix B — Mobile navigation graph

Root `main.dart` → `FixNowApp` → `MaterialApp` (navigatorKey `:608`, scaffoldMessengerKey `:610`, `_routeObserver` `:609`) → `ListenableBuilder(AuthController)` root swap.

| From | To | Mechanism |
| --- | --- | --- |
| Welcome | Auth | `onContinue(role, isRegister)` |
| Auth | Verification | `AuthStatus.verificationRequired` |
| Discovery | Sub-service catalog | `Navigator.push` |
| Catalog | Service request | `_handleProceed` |
| Discovery | Emergency confirm | `Navigator.push` |
| Any booking | Booking detail / tracking | `_bookingRoute` → `pushAndRemoveUntil` (tracking for `ASSIGNED`/`EN_ROUTE`/`IN_PROGRESS`) |
| Booking detail | Chat, invoice, reschedule, complaint, claim, book-again | `Navigator.push` / modal sheets |
| Provider home | Cockpit, navigation map, earnings, incoming request | `Navigator.push` |
| Notifications | Invoice / booking detail | card tap |
| — | Route restoration: `tracking` and `notifications` only, persisted to `fixnow.active_route` as `userId\|name\|arg`; cleared on sign-out and on userId mismatch |

## Appendix C — Mobile design-system ledger

89 public widgets; **56 referenced by production code, 33 never imported outside their own test**.

Dead (ship in the release binary, no import path): `FixStarRatingBurst`, `FixSlideToConfirm`, `FixSosVortexButton`, `EtaProgressRing`, `FixAudioWaveform`, `Fix3DSpatialBeacon`, `FixJourneyProgressLine`, `FixServiceCardGallery`, `FixProviderCardGallery`, `FixImage`, `FixOtpDisplay`, `FixAiPromptCard`, `FixInvoiceCard`, plus the private helpers behind them. `booking_lifecycle_views.dart` (4 dialogs incl. two fabricated providers) and `provider_setup_screen.dart` are likewise unreferenced. `fix_service_card_gallery.dart` and `fix_provider_card_gallery.dart` additionally ship **static sample provider/service records with fabricated ratings, prices, and an OTP**.