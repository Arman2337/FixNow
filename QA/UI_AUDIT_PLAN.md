# FixNow — Comprehensive UI Bug Audit and Runtime QA Plan

**Document Version:** 1.0.0  
**Audit Date:** 2026-10-13  
**Auditor Roles:** Senior QA Engineer, Flutter Mobile Engineer, Next.js Frontend Engineer, Accessibility Specialist  
**Repository Surfaces:**
- Customer Mobile App (`mobile/lib/`, Flutter Dart ≥3.10.8)
- Provider Mobile App (`mobile/lib/features/provider/`, Flutter Dart ≥3.10.8)
- Admin Web Dashboard (`admin/`, Next.js 16.3 App Router, React 19)
- Backend Core & Realtime Services (`backend/`, NestJS 11, TypeORM, PostgreSQL 16)
- Reverse Proxy (`scripts/proxy.ts`, Bun Engine)

---

## 1. System Architecture & Surface Inventory

### 1.1 Technical Stack & Runtime Topology
- **Customer & Provider Mobile Apps:** Flutter hybrid single-codebase with dynamic role-swapping navigation ladder (`mobile/lib/app.dart`). Uses custom `ChangeNotifier` state controllers, constructor dependency injection, and native Canvas drawing/raster map overlays.
- **Admin Operations Dashboard:** Next.js 16.3.6 App Router with React 19.2.8 and Tailwind CSS v4. Runs as all-Server-Components with granular Next.js Server Actions for operational mutations.
- **Backend API & WebSockets:** NestJS 11 on Express, running under global route prefix `/api/v1` with deny-by-default role guards. High-frequency bidirectional telemetry and signaling operates on `/realtime` via native `ws` gateway.
- **Reverse Proxy:** Bun-powered HTTP and WebSocket reverse proxy (`scripts/proxy.ts`) listening on port `8080` and routing to backend port `3300`.

### 1.2 Master Screen & UI Surface Inventory

#### A. Customer Mobile Screens (18 Screens)
1. `WelcomeScreen` (`auth/welcome_screen.dart`): Brand introduction and role switcher (Customer vs Technician).
2. `AuthScreen` (`auth/auth_screen.dart`): Segmented Sign-In / Account Registration with password visibility and referral expansion tile.
3. `VerificationScreen` (`auth/verification_screen.dart`): 6-digit email OTP challenge with 60s cooldown countdown.
4. `ServiceDiscoveryScreen` (`features/services/service_discovery_screen.dart`): Home discovery feed, emergency hotline banner, category cards, and offline cache banner.
5. `SubServiceCatalogScreen` (`features/services/sub_service_catalog_screen.dart`): Itemized sub-service catalog, quantity steppers, and floating cart summary sheet.
6. `ServiceRequestScreen` (`features/bookings/service_request_screen.dart`): Booking configuration, address selector, problem description, and slot picker.
7. `CustomerBookingsScreen` (`features/bookings/customer_bookings_screen.dart`): Active/Completed/Cancelled booking list, recurring schedule cards, and keyset pagination.
8. `BookingDetailScreen` (`features/bookings/booking_detail_screen.dart`): Realtime booking dossier, provider card, cancellation action, and dispute launcher.
9. `BookingTrackingScreen` (`features/tracking/booking_tracking_screen.dart`): Doorstep tracking hub, 4-digit service-start OTP display, and live map view.
10. `ProviderLiveMap` (`features/tracking/provider_live_map.dart`): OpenStreetMap raster tiles, provider route polyline, and vehicle beacon.
11. `BookingChatScreen` (`features/chat/booking_chat_screen.dart`): In-booking customer/provider text chat, delivery ticks, and polling fallback.
12. `ProblemDiagnosisScreen` (`features/ai/problem_diagnosis_screen.dart`): Multimodal AI scanner (camera photo capture, microphone audio recording, text description).
13. `CustomerHelpScreen` (`features/support/customer_help_screen.dart`): FAQ accordion, hotline dialer, and instant callback request.
14. `ComplaintListScreen` (`features/support/complaint_list_screen.dart`): Active support ticket tracker, status badges, and evidence view.
15. `SubmitComplaintScreen` (`features/support/submit_complaint_screen.dart`): Formal dispute filing form with category picker and description.
16. `NotificationCenterScreen` (`features/notifications/notification_center_screen.dart`): In-app inbox feed, category filters, and swipe-to-dismiss.
17. `EmergencyConfirmScreen` (`features/emergency/emergency_confirm_screen.dart`): 3-second hold-to-confirm SOS dispatch screen and wave status tracker.
18. `InvoiceScreen` (`features/payments/invoice_screen.dart`): Tax invoice breakdown, statutory GST itemization, PDF download, and share sheet.

#### B. Provider Mobile Screens (14 Screens)
1. `ProviderHomeScreen` (`features/provider/provider_home_screen.dart`): Technician home cockpit, online/offline availability switch, incoming request queue, and daily earnings summary.
2. `ProviderJobsScreen` (`features/provider/provider_jobs_screen.dart`): Multi-tab job manager (Urgent, Upcoming, History) with 7-day calendar strip.
3. `ProviderActiveJobCockpitScreen` (`features/provider/provider_active_job_cockpit_screen.dart`): Active on-site hub, customer address, line-item adjustments, photo proof modal, and OTP completion handshake.
4. `ProviderNavigationMapScreen` (`features/provider/provider_navigation_map_screen.dart`): Turn-by-turn navigation map, customer route, and arrival button.
5. `ProviderIncomingRequestScreen` (`features/provider/provider_incoming_request_screen.dart`): 30-second dispatch prompt, accept CTA, and skip action.
6. `ProviderEarningsScreen` (`features/provider/provider_earnings_screen.dart`): Financial dashboard, gross revenue, platform take-rate deduction, and net payout batch list.
7. `ProviderOnboardingScreen` (`features/provider/provider_onboarding_screen.dart`): 4-step technician registration wizard (Profile, Skills, Service Area Radius, KYC Document Upload).
8. `BookingReviewPanel` (`features/ratings/booking_review_panel.dart`): Provider rating submission and review photo upload sheet.
9. `SubmitClaimScreen` (`features/guarantees/ui/submit_claim_screen.dart`): 30-day warranty claim submission modal.
10. `CustomerProfileScreen` (`features/profile/customer_profile_screen.dart`): Profile name editor, saved addresses CRUD, and push notification toggles.
11. `LocationConsentCard` (`features/location/location_consent_card.dart`): Granular GPS permission explanation card.
12. `CallScreen` (`features/call/call_screen.dart`): In-app audio calling interface with mute and speakerphone controls.
13. `FixActiveBookingIsland` (`design_system/fix_active_booking_island.dart`): Persistent dynamic island widget floating above customer tab navigation.
14. `AppShell` (`app/app_shell.dart`): Persistent bottom navigation bar with role-specific tab items and unread badge counters.

#### C. Admin Web Dashboard Pages (18 Routes)
1. `/` (`admin/src/app/page.tsx`): Executive operations dashboard with 30-day KPIs and activity feed.
2. `/analytics` (`admin/src/app/analytics/page.tsx`): Detailed operational metrics and volume trends (Orphaned).
3. `/bookings` (`admin/src/app/bookings/page.tsx`): Realtime dispatch and booking queue with emergency alert banner.
4. `/bookings/[bookingId]` (`admin/src/app/bookings/[bookingId]/page.tsx`): Booking dossier, status history timeline, and force-cancellation modal.
5. `/providers` (`admin/src/app/providers/page.tsx`): Provider verification and KYC application queue.
6. `/providers/[applicationId]` (`admin/src/app/providers/[applicationId]/page.tsx`): Provider dossier, document review, claim button, and approve/reject decision form.
7. `/providers/[applicationId]/documents/[documentId]` (`admin/src/app/providers/[applicationId]/documents/[documentId]/route.ts`): Streaming private document proxy.
8. `/support` (`admin/src/app/support/page.tsx`): Customer complaint and dispute adjudication queue.
9. `/support/[complaintId]` (`admin/src/app/support/[complaintId]/page.tsx`): Case dossier, evidence viewer, and status transition adjudication form.
10. `/guarantees` (`admin/src/app/guarantees/page.tsx`): 30-day warranty claims list.
11. `/guarantees/[id]` (`admin/src/app/guarantees/[id]/page.tsx`): Guarantee claim dossier, resolution notes, and zero-cost re-service trigger.
12. `/services` (`admin/src/app/services/page.tsx`): Service category CRUD manager, icon editor, and baseline pricing editor.
13. `/trust` (`admin/src/app/trust/page.tsx`): Trust & safety signals queue and risk score table.
14. `/users` (`admin/src/app/users/page.tsx`): User account registry and role filter (Orphaned).
15. `/users/[userId]` (`admin/src/app/users/[userId]/page.tsx`): User account detail dossier and session list (Orphaned).
16. `/search` (`admin/src/app/search/page.tsx`): Global multi-entity search results page.
17. `/login` (`admin/src/app/login/page.tsx`): Staff authentication form.
18. `/unauthorized` (`admin/src/app/unauthorized/page.tsx`): Access denied 403 fallback page.

#### D. Dialogs, Modals & Action Sheets (27 Components)
- Customer Modals: `CancellationDialog`, `FixRescheduleSheet`, `FixOtpInputSheet`, `ServiceLocationPickerSheet`, `AddEditAddressModalSheet`, `SavedAddressSelectorCard`, `_CartSummarySheet`, `_showEmergencyGuidanceDialog`, `FixPaymentCheckoutSheet`, `FixShareInvoiceSheet`, `FixShareCelebration`, `_showSafetyModal`, `_CustomerLocationOptionsSheet`.
- Provider Modals: `FixProviderWorkingHoursSheet`, `_ServiceAdjustmentSheet`, `_handleAddExtraCharge`, `_requestServiceStartOtp`, `JobProofVerificationDialog`, `JobProofViewerCard`, `_handleCompleteService`, `FixAcceptCelebration`.
- Support & Shared: `_openProofModal`, `_confirmClearAll`, Support hotline dialog, Image-source sheet, `showFixBanner`.

---

## 2. Startup & Readiness Verification Strategy

### 2.1 Service Startup Protocol
1. **Local PostgreSQL:** Service runs on port `5432` (`localhost:5432/fixnow`). Verify connectivity via `SELECT 1`.
2. **NestJS Backend:** Launch via `npm run start:dev` in `backend/` on port `3300` (or `bun run scripts/dev.ts --backend-only`).
3. **Bun Reverse Proxy:** Launch via `bun run scripts/proxy.ts` on port `8080` (routes `/api/v1` and `/realtime` to port `3300`).
4. **Admin Dashboard:** Launch via `npm run dev` in `admin/` on port `3100`.
5. **Flutter Mobile:** Run `flutter run -d chrome --web-port 51354` in `mobile/` or run native Windows/device build.

### 2.2 Strict Readiness Checks (No "Started Process" Assumptions)
Before any UI interactions begin, verify:
- `GET http://localhost:3300/api/v1/health/liveness` returns `200 {"status":"ok"}`.
- `GET http://localhost:3300/api/v1/health/readiness` returns `200 {"status":"ok","database":"healthy"}`.
- `GET http://localhost:3100/login` returns `200 OK` (Next.js server responds).
- WebSocket handshake on `ws://localhost:3300/realtime` accepts initial frame without immediate drop.

---

## 3. Comprehensive UI & Runtime QA Test Dimensions

### 3.1 Visual & Layout Quality Checks
- **Overflow & Clipping:** Detect any Flutter `A RenderFlex overflowed by ... pixels` yellow/black tape errors or CSS layout breakages.
- **Responsive & Scaling:** Test mobile screens at 320dp (narrow phone), 375dp (standard), 414dp (large), and desktop/tablet viewports.
- **Safe Area & Overlap:** Verify app bars, floating buttons, dynamic island, and keyboard avoid overlapping bottom navigation and notches.
- **Typography & Assets:** Ensure absence of missing fonts, broken placeholder images, misaligned badges, or hardcoded strings that violate `DESIGN.md`.

### 3.2 Functional & Interaction Checks
- **Form Controls:** Test text inputs, validation limits (character bounds, regex), error message rendering, and clear buttons.
- **Interactive State Handlers:** Verify button loading spinners, disabled states during submission, and double-tap duplicate submission protection.
- **State Coverage:** Test each screen across 6 explicit states:
  1. *Loading / Skeleton State*
  2. *Populated / Normal State*
  3. *Empty State (Zero records)*
  4. *Error State (500 Server / 400 Bad Request)*
  5. *Offline State (Network unavailable)*
  6. *Permission Denied / Expired State (401 / 403)*

### 3.3 Role-Based Security & Navigation Gating
- **Customer Role:** Verify customer cannot access provider active cockpit or admin routes.
- **Provider Role:** Verify provider cannot accept jobs without active verified status.
- **Admin Roles:** Test RBAC segregation across staff roles:
  - `support_agent`: Verify access to `/support` and rejection on `/services`.
  - `service_catalog_manager`: Verify access to `/services` and rejection on `/support`.
  - `auditor`: Verify read-only enforcement and fix navigation mismatches.

### 3.4 Accessibility (a11y) Verification
- **Semantics:** Verify screen reader labels (`Semantics(label:)`) on icon-only buttons, service category tiles, and status indicators.
- **Touch Targets:** Verify minimum 48×48dp interactive touch target sizes across all mobile buttons.
- **Motion Reduction:** Ensure `MediaQuery.disableAnimations` and `prefers-reduced-motion` disable intense animations (`FixSosVortexButton`, `FixStarRatingBurst`).
- **Contrast & Hierarchy:** Check WCAG 2.1 AA compliant color contrast ratios across primary and secondary text.

---

## 4. Execution Workflow & Output Deliverables

The QA audit follows six progressive phases:
1. **Phase 1 (Completed):** Complete discovery, screen roster mapping, and creation of `QA/UI_AUDIT_PLAN.md`.
2. **Phase 2:** Launch backend, admin, and mobile services; verify HTTP/WebSocket readiness.
3. **Phase 3:** Execute visual, functional, and accessibility inspections across every screen and component.
4. **Phase 4:** Log all confirmed UI defects with exact reproduction steps in `QA/UI_BUG_REGISTER.md`.
5. **Phase 5:** Fix confirmed Critical and High severity UI defects; add regression tests; re-verify runtime behavior.
6. **Phase 6:** Generate comprehensive final QA report in `QA/UI_AUDIT_FINAL_REPORT.md`.
