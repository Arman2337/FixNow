<!-- CURRENT-RECONCILIATION-START -->
> **Superseded status claims — reconciled 2026-10-21.** The original audit below is retained as history. Its OPEN/FIXED labels, runtime assertions, scores, totals, paths and recommended patches are not current verification. Use [Current Reconciliation](FIXNOW_CURRENT_RECONCILIATION.md) and this file's [current disposition appendix](#current-dispositions-2026-10-21). Source fixes do not establish deployed database/device behavior. No application fixes were made by this reconciliation.
<!-- CURRENT-RECONCILIATION-END -->

# FixNow — Screen and UI Component Inventory

**Audit Date:** 2026-10-13  
**Audit Scope:** Every UI Screen, Page Route, Modal, Bottom Sheet, Dialog, and Design-System Widget across Customer Mobile, Provider Mobile, and Admin Web.  
**Source Locations:** `mobile/lib/`, `admin/src/app/`, `admin/src/components/`

---

## 1. Executive UI Surface Summary

The FixNow frontend architecture is divided into three distinct runtime surfaces:
1. **Customer Mobile Application:** 18 dedicated screens + 14 bottom sheets/dialogs + persistent navigation shell.
2. **Provider Mobile Application:** 14 dedicated screens + 9 action sheets/dialogs + active cockpit hub.
3. **Admin Web Dashboard:** 17 Server Component pages + 1 streaming route handler + staff navigation shell.
4. **Design System Widget Library:** 46 reusable custom Flutter widgets in `mobile/lib/design_system/`.

---

## 2. Customer Mobile Screen Inventory

### 2.1 `WelcomeScreen` (`auth/welcome_screen.dart`, 714 lines)
- **Route / Widget:** `WelcomeScreen`
- **Intended User:** Unauthenticated visitors & newly installed apps.
- **Purpose:** Onboarding entry; brand introduction; role selection between Customer and Service Provider.
- **Entry Points:** App launch when `AuthStatus.unauthenticated` or `initial`.
- **Actionable Controls:**
  - Role Selector Cards: "Need a Service" (Customer) vs "Provide a Service" (Technician).
  - "Get Started" CTA button with forward arrow icon.
  - "Already have an account? Sign In" text button.
- **Form Fields & Validation:** None.
- **States Handled:** Initial presentation, responsive scaling for small screens (<360dp width).
- **Dialogs & Confirmations:** None.
- **API Calls:** None directly (modifies `AuthController` role selection).
- **Status:** `IMPLEMENTED_EVIDENCED` (covered by `welcome_screen_test.dart`).

---

### 2.2 `AuthScreen` (`auth/auth_screen.dart`, 1102 lines)
- **Route / Widget:** `AuthScreen`
- **Intended User:** Unauthenticated customers & providers.
- **Purpose:** Combined Sign In and Registration screen with segmented mode switcher.
- **Entry Points:** Navigation from `WelcomeScreen` or forced re-auth from expired session.
- **Actionable Controls:**
  - Segmented Tab Bar: "Sign In" vs "Create Account".
  - Password Visibility Toggle: Eye icon button toggling `obscureText`.
  - Referral Code Expansion Tile: "Have a referral code? Get ₹150 OFF".
  - Quick Dev Login (Development Only): Chips for auto-filling test credentials (`customer-a`, `provider-a`, `reviewer`, `admin`).
  - Submit Button: "Sign In" / "Register Account" with embedded loading spinner.
  - Forgot Password Link: Opens password reset request modal.
- **Form Fields & Validation:**
  - Email: `TextFormField`, required, regex matching standard email format (<=254 chars).
  - Password: `TextFormField`, required, minimum 12 characters, max 128 characters.
  - Confirm Password (Register mode): Must match password exactly.
  - Referral Code: `TextFormField` (optional, uppercase).
- **States Handled:** Idle, loading (submit disabled, spinner visible), error banner (e.g., 401 Invalid Credentials, 429 Rate Limit Exceeded).
- **API Calls:** `POST /api/v1/auth/customer/login`, `POST /api/v1/auth/customer/register`, `POST /api/v1/auth/provider/login`, `POST /api/v1/auth/provider/register`.
- **Status & Defects:** `PARTIAL`. Registration and login work; referral code input is **inert** — `_referral.text` is collected but never passed to the registration API (GAP-45).

---

### 2.3 `VerificationScreen` (`auth/verification_screen.dart`, 735 lines)
- **Route / Widget:** `VerificationScreen`
- **Intended User:** Users in `pending_verification` state.
- **Purpose:** 6-digit email OTP challenge verification.
- **Entry Points:** Automatic navigation after registration or login with unverified email.
- **Actionable Controls:**
  - 6-Cell Pin Code Fields: Auto-advancing focus nodes; clipboard paste support.
  - Resend Code Action: Disabled during 60-second countdown; active text button once timer elapses.
  - "Biometric Quick Login" Switch: Switch tile with fingerprint icon.
  - Dev Bypass Button: Development-only bypass to skip OTP.
  - Back Button: Logs out current unverified session.
- **Form Fields & Validation:** 6 digits, numeric only.
- **States Handled:** Active cooldown timer, verifying spinner, invalid OTP error shake animation.
- **API Calls:** `POST /api/v1/auth/otp/verify`, `POST /api/v1/auth/otp/request`.
- **Status & Defects:** `PARTIAL`. Biometric switch is **inert** (GAP-45); OTP verification works.

---

### 2.4 `ServiceDiscoveryScreen` (`features/services/service_discovery_screen.dart`, 2731 lines)
- **Route / Widget:** `ServiceDiscoveryScreen` (Tab 0 of Customer Shell)
- **Intended User:** Authenticated customers.
- **Purpose:** Home screen, category browsing, search, active booking indicator, and rebooking.
- **Entry Points:** Default tab upon login.
- **Actionable Controls:**
  - Address Selector Header: Tap to open `ServiceLocationPickerSheet`.
  - Notification Bell Icon: Badge counter; tap opens `NotificationCenterScreen`.
  - Offline Saved-Data Banner: Renders when offline; retry button triggers catalog refresh.
  - `FixUniversalSearchBar`: Live search field with clear button; filter chips for Budget, Emergency, Top Rated.
  - Quick Category Icons Row: Plumbing, Electrical, HVAC, Cleaning, Emergency.
  - Rebook Carousel: Horizontal cards of past bookings with one-tap "Book Again" CTA.
  - Category Cards Grid: Service cards rendering image, title, rating, review count, and `priceFrom`.
  - Emergency SOS Banner: Direct navigation to `EmergencyConfirmScreen`.
  - Emergency Hotline Banner: Displays emergency contact number with "Call Now" button.
- **States Handled:** Shimmer skeleton loading, offline saved-data banner with timestamp, empty search results view, live connected catalog.
- **API Calls:** `GET /api/v1/service-categories/active`, `GET /api/v1/bookings` (for rebook row).
- **Status & Defects:** `IMPLEMENTED_EVIDENCED`. Hotline now guarded by environment configuration.

---

### 2.5 `SubServiceCatalogScreen` (`features/services/sub_service_catalog_screen.dart`, 1323 lines)
- **Route / Widget:** `SubServiceCatalogScreen`
- **Intended User:** Customers selecting specific services.
- **Purpose:** Itemized sub-service selection within a category with quantity steppers and cart drawer.
- **Entry Points:** Tapping a category card from `ServiceDiscoveryScreen`.
- **Actionable Controls:**
  - Back Button: Returns to category list.
  - Filter Chips: Sub-category filters (e.g., Repair, Installation, Maintenance).
  - Sub-Service Card Steppers: Quantity `+` and `-` buttons; item count display.
  - Sticky Cart Bar: Renders total item count and price; tap expands `_CartSummarySheet`.
  - "Proceed to Booking" Button: Hands off cart payload to `ServiceRequestScreen`.
- **Form Fields & Validation:** Quantity minimum 0, max 10 per line item.
- **States Handled:** Loading skeleton, empty category notice, floating cart slide-up.
- **API Calls:** `GET /api/v1/sub-services?categoryId=<id>`.
- **Status:** `IMPLEMENTED_EVIDENCED` (covered by `sub_service_catalog_screen_test.dart`).

---

### 2.6 `ServiceRequestScreen` (`features/bookings/service_request_screen.dart`, 663 lines)
- **Route / Widget:** `ServiceRequestScreen`
- **Intended User:** Customers finalizing a booking request.
- **Purpose:** Request details configuration (schedule, address, description, notes).
- **Entry Points:** Tapping "Book Now" from cart or category card.
- **Actionable Controls:**
  - Schedule Date & Time Picker: Tap opens calendar and slot picker sheet.
  - Address Picker Tile: Selects saved address or creates new address.
  - Problem Description Input: Multiline text area.
  - Advisory Price Estimate Card: Renders AI/historical price range estimate.
  - Submit Button: "Confirm & Request Service" with loading spinner.
- **Form Fields & Validation:** Description minimum 10 characters; schedule slot must be in the future; address selection mandatory.
- **States Handled:** Validating, submitting, error dialog on scheduling conflict.
- **API Calls:** `POST /api/v1/bookings`, `GET /api/v1/ai/price-estimate`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 2.7 `CustomerBookingsScreen` (`features/bookings/customer_bookings_screen.dart`, 1704 lines)
- **Route / Widget:** `CustomerBookingsScreen` (Tab 1 of Customer Shell)
- **Intended User:** Customers tracking past and present bookings.
- **Purpose:** Full bookings list with status tabs and recurring subscription management.
- **Entry Points:** Bottom navigation bar tab 1.
- **Actionable Controls:**
  - Status Tab Bar: `Active`, `Completed`, `Cancelled`.
  - Pull-to-Refresh: Refreshes bookings history.
  - Booking Card: Tap navigates to `BookingDetailScreen`.
  - "Track Technician" Button (Active cards): Opens `BookingTrackingScreen`.
  - "Pay Now" Button (Completed, unpaid cards): Opens `InvoiceScreen`.
  - Recurring Schedule Section: Expandable section managing recurring bookings with Pause/Resume/Cancel actions.
- **States Handled:** Shimmer loading skeleton, empty tab state ("No active bookings"), error view with retry button.
- **API Calls:** `GET /api/v1/bookings`, `GET /api/v1/bookings/schedules`, `PATCH /api/v1/bookings/schedules/:id/status`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 2.8 `BookingDetailScreen` (`features/bookings/booking_detail_screen.dart`, 1199 lines)
- **Route / Widget:** `BookingDetailScreen`
- **Intended User:** Customer inspecting a single booking.
- **Purpose:** Complete dossier: status stepper, technician card, line items, actions, dispute filing, review.
- **Entry Points:** Tapping any booking card in `CustomerBookingsScreen`.
- **Actionable Controls:**
  - Status Progress Stepper: Visual 5-stage progress indicator.
  - Call Technician Button: Launches in-app call or phone dialer.
  - Message Technician Button: Navigates to `BookingChatScreen`.
  - Cancel Booking Button: Opens `CancellationDialog`.
  - Reschedule Button: Opens `FixRescheduleSheet`.
  - View Invoice Button: Navigates to `InvoiceScreen`.
  - File Guarantee Claim Button: Opens `SubmitClaimScreen`.
  - Rate & Review Panel: Star rating and photo attachment submission.
- **States Handled:** Loading, state transitions via WebSocket updates, cancelled view.
- **API Calls:** `GET /api/v1/bookings/:id`, `POST /api/v1/bookings/:id/cancel`, `POST /api/v1/bookings/:id/reschedule`.
- **Status & Defects:** `IMPLEMENTED_EVIDENCED`. Call technician button launches dead call repository (GAP-51).

---

### 2.9 `BookingTrackingScreen` (`features/tracking/booking_tracking_screen.dart`, 1771 lines)
- **Route / Widget:** `BookingTrackingScreen`
- **Intended User:** Customer awaiting technician arrival.
- **Purpose:** Live GPS map tracking, ETA countdown, arrival notification, and start OTP display.
- **Entry Points:** "Track" button on active booking card or detail screen.
- **Actionable Controls:**
  - Live Map: OpenStreetMap canvas with technician vehicle marker and route polyline.
  - Recenter GPS Button: Floats over map to re-focus user's location.
  - Start Service Security OTP Card: Large 4-digit code display with security advisory copy.
  - Technician Contact Row: Call button, chat button.
  - Emergency SOS Button: Quick emergency escalation trigger.
- **States Handled:** Reconnecting socket banner, arrival celebration modal, stale GPS indicator.
- **API Calls:** WebSocket `location-update`, `POST /api/v1/bookings/:id/service-start-otp`.
- **Status & Defects:** `IMPLEMENTED_EVIDENCED`. Uses hardcoded Google avatar URL for customer icon (GAP-30); dispatch fee policy copy in UI contradicts cancellation dialog (GAP-48).

---

### 2.10 `BookingChatScreen` (`features/chat/booking_chat_screen.dart`, 760 lines)
- **Route / Widget:** `BookingChatScreen`
- **Intended User:** Customer and Provider.
- **Purpose:** In-booking real-time chat.
- **Entry Points:** Chat icon button in booking tracking or detail screens.
- **Actionable Controls:**
  - Message Feed: Bubble stream with sent/delivered/read status ticks.
  - Text Input Field: Message composer (max 2000 chars).
  - Send Button: Paper airplane icon; disabled when text is empty.
  - Auto-scroll to Bottom Button: Appears when scrolled up.
- **States Handled:** Loading history, empty chat state, message send failure retry.
- **API Calls:** `GET /api/v1/bookings/:id/messages`, `POST /api/v1/bookings/:id/messages`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 2.11 `ProblemDiagnosisScreen` (`features/ai/problem_diagnosis_screen.dart`, 822 lines)
- **Route / Widget:** `ProblemDiagnosisScreen`
- **Intended User:** Customer seeking automated diagnostics.
- **Purpose:** Multimodal AI diagnosis using photos and voice notes.
- **Entry Points:** "AI Diagnosis" button in home search bar and category header.
- **Actionable Controls:**
  - Camera Capture Button: Takes photo of damaged appliance.
  - Gallery Picker Button: Selects existing photo.
  - Voice Record Button: Hold to record audio description of problem.
  - Analyze Button: Submits multimodal payload to backend AI pipeline.
  - Result Card: Displays problem classification, severity, suggested category, and "Book This Service" CTA.
- **States Handled:** Audio recording waveform, photo scanner animation overlay, analysis spinner, fallback error view.
- **API Calls:** `POST /api/v1/ai/problem-analysis/combined`, `POST /api/v1/ai/service-recommendation`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 2.12 `CustomerHelpScreen` (`features/support/customer_help_screen.dart`, 1127 lines)
- **Route / Widget:** `CustomerHelpScreen` (Tab 2 of Customer Shell)
- **Intended User:** Customers seeking support.
- **Purpose:** FAQ browsing, support hotline, complaint filing, callback request.
- **Entry Points:** Bottom navigation tab 2.
- **Actionable Controls:**
  - FAQ Search Field: Live client filter over FAQs.
  - Expandable FAQ Accordions: 5 static FAQ entries.
  - "File a Dispute / Complaint" Card: Navigates to `SubmitComplaintScreen`.
  - "View Past Complaints" Card: Navigates to `ComplaintListScreen`.
  - "Call Support" Button: Dials statutory hotline.
  - "Request Instant Callback" Button: Opens callback modal.
- **States Handled:** Idle, expanded accordion states.
- **API Calls:** None directly on main view.
- **Status & Defects:** `PARTIAL`. "Request Instant Callback" opens a modal claiming unavailable, despite a live `POST /support/complaints/:id/callback-request` endpoint existing (GAP-45).

---

### 2.13 `ComplaintListScreen` (`features/support/complaint_list_screen.dart`, 1186 lines)
- **Route / Widget:** `ComplaintListScreen`
- **Intended User:** Customers tracking filed disputes.
- **Purpose:** Listing customer's filed complaints and current resolution status.
- **Entry Points:** Help screen link.
- **Actionable Controls:**
  - Complaint Card: Shows complaint reference ID, booking ID, status badge (`SUBMITTED`, `INVESTIGATING`, `RESOLVED`).
  - Evidence Upload Modal Trigger: Attach further photo evidence.
- **States Handled:** Loading, empty complaints list, resolved details sheet.
- **API Calls:** `GET /api/v1/support/complaints`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 2.14 `SubmitComplaintScreen` (`features/support/submit_complaint_screen.dart`, 242 lines)
- **Route / Widget:** `SubmitComplaintScreen`
- **Intended User:** Customer reporting service defect or misconduct.
- **Purpose:** Dispute submission form.
- **Entry Points:** Help screen or booking detail screen.
- **Actionable Controls:**
  - Complaint Category Dropdown: Overcharging, Poor Quality, Property Damage, Unprofessional Behavior.
  - Description Text Box: Detailed explanation (min 20 chars).
  - Photo Attachment Picker: Attach evidence photos.
  - Submit Button: Sends complaint to admin support queue.
- **States Handled:** Submitting spinner, success dialog with ticket ID.
- **API Calls:** `POST /api/v1/support/complaints`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 2.15 `NotificationCenterScreen` (`features/notifications/notification_center_screen.dart`, 860 lines)
- **Route / Widget:** `NotificationCenterScreen`
- **Intended User:** Customer & Provider.
- **Purpose:** In-app notification feed.
- **Entry Points:** Bell icon in top app bar.
- **Actionable Controls:**
  - Filter Chips: All, Bookings, System, Security.
  - Notification Item: Tap marks read; swipe left dismisses.
  - "Clear All" Button: Text button in app bar with confirmation dialog.
- **States Handled:** Empty inbox, unread indicator dot.
- **API Calls:** `GET /api/v1/users/:id/notifications`, `PATCH /api/v1/users/:id/notifications/:id/read`.
- **Status & Defects:** `PARTIAL`. "Clear All" deletes items from a local in-memory set only; returns on next app restart because backend has no delete endpoint (GAP-43, GAP-56).

---

### 2.16 `EmergencyConfirmScreen` (`features/emergency/emergency_confirm_screen.dart`, 887 lines)
- **Route / Widget:** `EmergencyConfirmScreen`
- **Intended User:** Customer experiencing acute safety hazard.
- **Purpose:** SOS emergency request initiation.
- **Entry Points:** Emergency button in discovery header and tracking screen.
- **Actionable Controls:**
  - Hold-to-Confirm Circular Vortex Button: 3-second animated press threshold.
  - Category Selector: Gas Leak, Water Flooding, Electrical Fire Hazard.
  - Immediate Cancel Button: Available during 5-second post-confirmation window.
  - Wave Tracker View: Shows broadcast waves expanding across radius.
- **States Handled:** Holding animation, broadcast wave animation, provider assigned transition.
- **API Calls:** `POST /api/v1/emergency/requests`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 2.17 `InvoiceScreen` (`features/payments/invoice_screen.dart`, 628 lines)
- **Route / Widget:** `InvoiceScreen`
- **Intended User:** Customer viewing bill.
- **Purpose:** Payment status, invoice download, share sheet, payment trigger.
- **Entry Points:** Booking detail screen, bookings list, notification tap.
- **Actionable Controls:**
  - Status Banner: Paid, Pending, Refunded.
  - Breakdown Table: Base fare, additional parts, GST (18%), total.
  - "Pay Now (Interactive Checkout)" Button: Gated behind dev check `_canPayLocally`.
  - "Download PDF Invoice" Button: Generates and saves PDF to device storage.
  - "Share Invoice" Button: Opens native platform share sheet.
- **States Handled:** Pending payment state, paid receipt state, downloading spinner.
- **API Calls:** `GET /api/v1/payments/invoices/:orderId`, `GET /api/v1/payments/orders/booking/:id`.
- **Status & Defects:** `IMPLEMENTED_EVIDENCED`. GSTIN in generated PDF is a static placeholder, and address contradicts header copy (GAP-42).

---

### 2.18 `CustomerProfileScreen` (`features/profile/customer_profile_screen.dart`, 974 lines)
- **Route / Widget:** `CustomerProfileScreen` (Tab 3 of Customer Shell)
- **Intended User:** Authenticated customer.
- **Purpose:** Profile settings, address management, notification preferences, logout.
- **Entry Points:** Bottom navigation tab 3.
- **Actionable Controls:**
  - Display Name Input Field & Save Button.
  - Phone Number Display (Read-only).
  - Saved Addresses List: Add address button, delete address icon, set default radio.
  - Push Notification Settings Expansion Card: Toggle switches for marketing and system push.
  - Payment Methods Row: Navigational chevron row.
  - Logout Button: Destructive red button with confirmation dialog.
- **Form Fields & Validation:** Display name 1-80 characters, no control characters.
- **States Handled:** Loading, saving spinner, success toast.
- **API Calls:** `GET /api/v1/users/me/profile`, `PATCH /api/v1/users/me/profile`, `GET /api/v1/users/me/addresses`.
- **Status & Defects:** `PARTIAL`. Payment Methods row has **no `onTap` gesture detector** (GAP-45); push switches only update local `setState` without API persistence (GAP-45).

---

## 3. Provider Mobile Screen Inventory

### 3.1 `ProviderHomeScreen` (`features/provider/provider_home_screen.dart`, 1128 lines)
- **Route / Widget:** `ProviderHomeScreen` (Tab 0 of Provider Shell)
- **Intended User:** Verified service technician.
- **Purpose:** Duty toggle, incoming job requests feed, accept-time signal badge, quick earnings.
- **Entry Points:** Default tab for verified providers.
- **Actionable Controls:**
  - Duty Status Switch: Online / Busy / Offline.
  - Live Accept-Time Badge: "Fast Responder (<45s)" trust rating indicator.
  - Incoming Request Feed: List of dispatched service requests within radius.
  - "Accept Job" Action Button: Immediate atomic claim.
  - "View Details" Action Button: Opens `ProviderIncomingRequestScreen`.
- **States Handled:** Offline prompt ("Go online to receive requests"), empty requests radar animation.
- **API Calls:** `PUT /api/v1/provider-availability/me/status`, `GET /api/v1/trust/my-accept-time`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 3.2 `ProviderJobsScreen` (`features/provider/provider_jobs_screen.dart`, 1908 lines)
- **Route / Widget:** `ProviderJobsScreen` (Tab 1 & Tab 2 of Provider Shell)
- **Intended User:** Verified service technician.
- **Purpose:** Jobs management queue (Active jobs in Tab 1, Completed history in Tab 2).
- **Entry Points:** Bottom navigation tabs 1 and 2.
- **Actionable Controls:**
  - 7-Day Calendar Strip Picker: Monday through Sunday selector.
  - Job Card: Customer address, service category, price, ETA.
  - "Open Cockpit" Button: Launches `ProviderActiveJobCockpitScreen`.
  - "Navigate" Button: Launches `ProviderNavigationMapScreen`.
- **States Handled:** Empty history, loading skeleton.
- **API Calls:** `GET /api/v1/bookings/available`, `GET /api/v1/bookings`.
- **Status & Defects:** `PARTIAL`. 7-day strip picker is cosmetic: `onTap` updates styling index but does **not filter** `currentJobs` (GAP-24, GAP-68).

---

### 3.3 `ProviderActiveJobCockpitScreen` (`features/provider/provider_active_job_cockpit_screen.dart`, 1927 lines)
- **Route / Widget:** `ProviderActiveJobCockpitScreen`
- **Intended User:** Provider executing an assigned job.
- **Purpose:** Mission control for live service execution.
- **Entry Points:** Pushed when technician accepts a job or taps "Open Cockpit".
- **Actionable Controls:**
  - "Start Journey" Button: Transitions state to `EN_ROUTE`.
  - "Arrived at Location" Button: Notifies customer of arrival.
  - "Verify Start OTP" Button: Opens `FixOtpInputSheet` dialog to input customer's 4-digit code.
  - "Add Extra Charges / Line Items" Button: Opens line item adjustment sheet.
  - "Capture Job Proof Photos" Button: Opens before/after photo dialog.
  - "Complete Service" Button: Opens completion confirmation dialog and prompts final sign-off.
  - Customer Phone Icon: Launches dialer.
  - Customer Chat Icon: Opens `BookingChatScreen`.
- **States Handled:** Status progression transitions, OTP verification loading, proof photo upload progress.
- **API Calls:** `PATCH /api/v1/bookings/:id/status`, `POST /api/v1/bookings/:id/start-service`, `PUT /api/v1/bookings/:id/line-items`.
- **Status & Defects:** `IMPLEMENTED_EVIDENCED`. Cancel guard bug on OTP dialog identified in GAP-03 (`shouldContinue != true && !mounted`).

---

### 3.4 `ProviderNavigationMapScreen` (`features/provider/provider_navigation_map_screen.dart`, 479 lines)
- **Route / Widget:** `ProviderNavigationMapScreen`
- **Intended User:** Provider en route to customer.
- **Purpose:** Turn-by-turn road navigation map.
- **Entry Points:** "Navigate" action in cockpit or jobs screen.
- **Actionable Controls:**
  - Full-Screen OSM Map: Route polyline from current position to destination.
  - Turn Instruction Header: Next maneuver indicator and distance remaining.
  - "Open in Google Maps / Apple Maps" Button.
  - "Verify OTP" Bottom Shortcut.
- **States Handled:** GPS acquisition spinner, route re-calculation banner.
- **API Calls:** OpenRouteService direction API.
- **Status & Defects:** `PARTIAL`. Native `url_launcher_stub.dart` does nothing on Android/iOS devices when "Open in External Maps" is tapped (GAP-22).

---

### 3.5 `ProviderIncomingRequestScreen` (`features/provider/provider_incoming_request_screen.dart`, 285 lines)
- **Route / Widget:** `ProviderIncomingRequestScreen`
- **Intended User:** Provider receiving an inbound dispatch.
- **Purpose:** Full-screen incoming job alert with audio cue and countdown.
- **Entry Points:** Pushed by WebSocket notification listener.
- **Actionable Controls:**
  - 30-Second Animated Radial Countdown.
  - "Accept Job" Slide-to-Confirm / Button.
  - "Decline / Skip" Text Button.
  - Map Preview: Distance to job and approximate customer locality.
- **States Handled:** Expired state (auto-dismisses after 30 seconds), accepting spinner.
- **API Calls:** `POST /api/v1/bookings/:id/accept`.
- **Status & Defects:** `IMPLEMENTED_EVIDENCED`. Audio tone MethodChannel has no caller (GAP-39).

---

### 3.6 `ProviderEarningsScreen` (`features/provider/provider_earnings_screen.dart`, 502 lines)
- **Route / Widget:** `ProviderEarningsScreen`
- **Intended User:** Provider reviewing finances.
- **Purpose:** Earnings breakdown, platform commission audit, and payouts.
- **Entry Points:** Quick earnings card on home tab or profile tab.
- **Actionable Controls:**
  - Period Filter: "This Week", "This Month", "All Time".
  - Gross Earnings Card, Platform Deductions Card, Net Payable Card.
  - Individual Completed Job List with payout amounts.
- **States Handled:** Loading, empty earnings history.
- **API Calls:** `GET /api/v1/providers/me/earnings`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 3.7 `ProviderOnboardingScreen` (`features/provider/provider_onboarding_screen.dart`, 1995 lines)
- **Route / Widget:** `ProviderOnboardingScreen`
- **Intended User:** Newly registered technician (`provider_applicant`).
- **Purpose:** 4-Step KYC and verification onboarding wizard.
- **Entry Points:** Root navigation swap when role is `provider_applicant`.
- **Actionable Controls:**
  - Step 1 (Personal & Trade): Full name, years of experience, trade category picker.
  - Step 2 (Service Radius): Slider selecting operating radius (1 km to 100 km).
  - Step 3 (KYC Documents): Camera / gallery upload buttons for Government ID and Trade License.
  - Step 4 (Review & Submit): Terms agreement checkbox and "Submit for Verification" button.
- **Form Fields & Validation:** Experience >=0, radius 1-100, documents <=10 MiB, terms accepted.
- **States Handled:** Step navigation, document uploading progress, submitted approval pending view.
- **API Calls:** `POST /api/v1/provider-documents/:type`, `POST /api/v1/provider-applications/me/submit`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 3.8 Dead / Unreachable Mobile Screens
| Screen Name | File Path | Lines | Reason Unreachable | Severity |
|---|---|---|---|---|
| `AiDiagnosticScreen` | `features/ai/ai_diagnostic_screen.dart` | 420 | Superseded by `ProblemDiagnosisScreen`; no imports from production code | P1 (GAP-50) |
| `AiRecommendationScreen` | `features/ai/ai_recommendation_screen.dart` | 380 | Superseded by inline problem analysis view; dead file | P1 (GAP-50) |
| `ComplaintDetailScreen` | `features/support/complaint_detail_screen.dart` | 567 | Imported only by test fixtures; live app uses bottom sheet | P1 (GAP-50) |
| `ProviderSetupScreen` | `features/provider/provider_setup_screen.dart` | 397 | Legacy onboarding screen; superseded by `ProviderOnboardingScreen` | P1 (GAP-50) |
| `ProviderOnboardingEntryScreen` | `auth/provider_onboarding_entry_screen.dart` | 72 | Dead wrapper; app swaps directly to `ProviderOnboardingScreen` | P1 (GAP-50) |
| `BookingTrackingOverviewScreen` | `features/tracking/booking_tracking_overview_screen.dart` | 48 | Empty placeholder stub; no callers | P1 (GAP-50) |

---

## 4. Admin Web Dashboard Screen Inventory

### 4.1 `/` — Operations Dashboard (`admin/src/app/page.tsx`, 112 lines)
- **Route:** `/`
- **Intended User:** Operations Administrator & Platform Auditor.
- **Purpose:** High-level platform health, live dispatches, active counts, revenue.
- **Actionable Controls:**
  - Date Range Dropdown: Today, 7 Days, 30 Days.
  - Metric Cards: Total Bookings, Open Disputes, Pending KYC Reviews, Gross Volume.
  - Quick Link Buttons: "View Dispatch Queue", "Review Complaints", "Verify Providers".
- **API Calls:** `GET /api/v1/admin/analytics`.
- **Role Guard:** `operations_administrator`, `auditor`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 4.2 `/bookings` — Bookings Queue (`admin/src/app/bookings/page.tsx`, 128 lines)
- **Route:** `/bookings`
- **Intended User:** Operations Staff & Dispatchers.
- **Purpose:** Central dispatch queue monitoring.
- **Actionable Controls:**
  - Status Filter Tabs: All, Requested, Assigned, En Route, Completed, Cancelled.
  - Emergency Alert Banner: Computes count of active emergency jobs.
  - Bookings Table: Columns for Booking ID, Customer, Category, Status, Created At.
- **States Handled:** Empty table, loading skeleton.
- **API Calls:** `GET /api/v1/admin/bookings?limit=20`.
- **Defects & Limitations:**
  - **No code-level role check** in page component (GAP-05).
  - Table rows are plain `<tr>` elements — **not clickable links** to `/bookings/[bookingId]` (GAP-27).
  - Lacks a "Load More" / pagination control (GAP-25).
  - Emergency count computed via string matching `"emergency"` in description (GAP-20).

---

### 4.3 `/bookings/[bookingId]` — Booking Dossier (`admin/src/app/bookings/[bookingId]/page.tsx`, 164 lines)
- **Route:** `/bookings/[bookingId]`
- **Intended User:** Trust & Safety Reviewer, Operations Administrator.
- **Purpose:** Full audit dossier of single booking with intervention capability.
- **Actionable Controls:**
  - Customer & Provider Identity Dossiers.
  - Event Audit Timeline: Every state transition timestamp.
  - Administrative Cancel Button: Prompts for mandatory audit reason; forces terminal state.
- **API Calls:** `GET /api/v1/admin/bookings/:id`, `POST /api/v1/admin/bookings/:id/cancel`.
- **Role Guard:** Code-level check for `trust_safety_reviewer` or `operations_administrator`.
- **Status:** `IMPLEMENTED_UNVERIFIED` (route has no tests, GAP-87).

---

### 4.4 `/providers` — KYC Verification Queue (`admin/src/app/providers/page.tsx`, 140 lines)
- **Route:** `/providers`
- **Intended User:** Provider Reviewer, Operations Administrator.
- **Purpose:** Queue of submitted technician KYC applications.
- **Actionable Controls:**
  - Status Tabs: Pending Review, Approved, Rejected, Resubmission Requested.
  - Application Row: Applicant name, trade skills, submission date; link to `/providers/[applicationId]`.
  - Pagination Button: "Load More Records" (uses keyset cursor).
- **API Calls:** `GET /api/v1/admin/provider-applications`.
- **Defects & Limitations:**
  - Right 40% of layout is occupied by a permanent static placeholder box ("RIGHT PANE: Placeholder Dossier") (GAP-28).
  - No code-level role check in page component (GAP-05).

---

### 4.5 `/providers/[applicationId]` — KYC Dossier & Decision (`admin/src/app/providers/[applicationId]/page.tsx`, 210 lines)
- **Route:** `/providers/[applicationId]`
- **Intended User:** Provider Reviewer, Operations Administrator.
- **Purpose:** Detailed document inspection and verification decision form.
- **Actionable Controls:**
  - Claim Application Button: Claims application under reviewer's user ID.
  - Document Viewer: In-page thumbnail and full-document proxy view.
  - Decision Form:
    - Radio Buttons: `Approve`, `Reject`, `Request Resubmission`.
    - Decision Reason Input: Text field (mandatory, min 3 chars).
    - Submit Decision Button: Updates state and activates provider role if approved.
- **API Calls:** `POST /api/v1/admin/provider-applications/:id/claim`, `POST .../decision`.
- **Role Guard:** `provider_reviewer`, `operations_administrator`.
- **Status:** `IMPLEMENTED_EVIDENCED`.

---

### 4.6 `/support` — Complaints Queue (`admin/src/app/support/page.tsx`, 155 lines)
- **Route:** `/support`
- **Intended User:** Support Agents & Operations Administrators.
- **Purpose:** Queue of customer dispute tickets.
- **Actionable Controls:**
  - Complaints Table: Complaint ID, submitter, category, priority, status badge.
  - Filter Tabs: All, Open, Under Investigation, Resolved.
- **API Calls:** `GET /api/v1/admin/complaints` (**unpaginated**).
- **Defects & Limitations:**
  - Fetches the entire complaint database in full with no `limit` or `take` (GAP-23).
  - Navigation permits `auditor` role, but backend rejects auditor with 403 (GAP-06).
  - Layout contains duplicate permanent static placeholder pane (GAP-28).

---

### 4.7 `/support/[complaintId]` — Dispute Adjudication (`admin/src/app/support/[complaintId]/page.tsx`, 245 lines)
- **Route:** `/support/[complaintId]`
- **Intended User:** Support Agent, Operations Administrator.
- **Purpose:** Case evidence investigation, status transition, refund issuance.
- **Actionable Controls:**
  - Case Timeline: Customer complaint, technician rebuttal, attached photos.
  - Status Transition Dropdown: Selects next legal status using `nextComplaintStatuses()`.
  - Issue Refund Button: Opens refund modal with amount field and mandatory idempotency key.
- **API Calls:** `PATCH /api/v1/admin/complaints/:id/status`, `POST /api/v1/admin/payments/orders/:id/refunds`.
- **Role Guard:** `support_agent`, `operations_administrator`, `security_administrator`.
- **Defects:** Submitter name and target name render blank because `UserDetail` type promises fields backend never returns (GAP-17, GAP-73).

---

### 4.8 `/trust` — Trust & Safety Queue (`admin/src/app/trust/page.tsx`, 120 lines)
- **Route:** `/trust`
- **Intended User:** Trust & Safety Reviewers.
- **Purpose:** Moderating fraud alerts and provider accept-time anomalies.
- **Actionable Controls:**
  - Signal Alert Table: Provider ID, signal type (`ACCEPT_TIME_ANOMALY`, `PRICE_FRAUD`), severity score.
  - Review Action Form: Dismiss, Acknowledge, Escalate buttons.
- **API Calls:** `GET /api/v1/admin/trust/signals` (hardcoded take 100), `PATCH /api/v1/admin/trust/signals/:id`.
- **Critical Defect:** **No code-level role check at all** (GAP-05). Any authenticated staff member can view this page directly.

---

### 4.9 `/services` — Catalog & Pricing Admin (`admin/src/app/services/page.tsx`, 180 lines)
- **Route:** `/services`
- **Intended User:** Service Catalog Managers & Operations Administrators.
- **Purpose:** Managing categories and base prices.
- **Actionable Controls:**
  - Category Creation Form: Name, slug, description, icon name, emergency checkbox.
  - Pricing Configuration: Set base starting price, currency INR.
  - Sub-Services Table: View configured sub-services per category.
  - Delete Category Button: Cascading delete action.
- **API Calls:** `POST /api/v1/admin/service-categories`, `PUT ...`, `DELETE ...`.
- **Defects:**
  - Forms render for `auditor` who gets 403 on every submit (GAP-06).
  - Review and photo moderation endpoints have **no UI on this or any other page** (GAP-57).

---

### 4.10 `/guarantees/[id]` — Guarantee Claim Case (`admin/src/app/guarantees/[id]/page.tsx`, 190 lines)
- **Route:** `/guarantees/[id]`
- **Intended User:** Operations Staff.
- **Purpose:** Guarantee warranty adjudication and re-service scheduling.
- **Actionable Controls:**
  - Status Dropdown: All 6 statuses rendered.
  - "Trigger Re-Service Booking" Button: Automatically spawns a linked free booking.
- **API Calls:** `PATCH /api/v1/guarantees/claims/:id/status`, `POST /api/v1/guarantees/claims/:id/re-service`.
- **Defects:**
  - Status dropdown has no transition table and offers illegal transitions (e.g. `COMPLETED -> PENDING`), causing 409 errors (GAP-07, GAP-58).
  - Server actions `throw` rather than redirecting, crashing into `error.tsx` (GAP-21).

---

### 4.11 Fully Orphaned Admin Routes
- **`/analytics` (`app/analytics/page.tsx`):** Functional reporting page, but **zero links** point to it anywhere in the application (GAP-54).
- **`/users` (`app/users/page.tsx`):** Complete user directory table with role filters, but **zero links** exist in navigation (GAP-54).
- **`/users/[userId]` (`app/users/[userId]/page.tsx`):** User dossier page; unreachable except via manual URL entry or guarantee page link (GAP-54).

---

## 5. Design System Widget Library Inventory (`mobile/lib/design_system/`)

| Widget Name | File Path | Lines | Key Controls & Behaviors | Status |
|---|---|---|---|---|
| `FixButton` | `fix_button.dart` | 240 | Primary, secondary, text styles; embedded loading spinner; squish press scale | `IMPLEMENTED_EVIDENCED` |
| `FixUniversalSearchBar` | `fix_universal_search_bar.dart` | 310 | Text input, clear button, horizontal filter chip list, price threshold filters | `IMPLEMENTED_EVIDENCED` |
| `FixServiceCard` | `fix_service_card.dart` | 890 | Shimmer image preview, rating badge, compact review count, price from, tap feedback | `IMPLEMENTED_EVIDENCED` |
| `FixProviderCard` | `fix_provider_card.dart` | 720 | Provider avatar, verified badge, distance chip, accept-time signal, hourly rate | `IMPLEMENTED_EVIDENCED` |
| `FixActiveBookingIsland` | `fix_active_booking_island.dart` | 195 | Floating dynamic island, pulse animation, arrival ETA text, tap-to-navigate | `IMPLEMENTED_EVIDENCED` |
| `FixSavedDataBanner` | `fix_saved_data_banner.dart` | 116 | Offline alert banner, timestamp of cached copy, manual retry button | `IMPLEMENTED_EVIDENCED` |
| `FixRebookRow` | `rebook_row.dart` | 203 | Horizontal carousel of past completed bookings with one-tap rebook CTA | `IMPLEMENTED_EVIDENCED` |
| `FixAddressSelector` | `fix_address_selector.dart` | 650 | Radio list of saved addresses, default badge, add new address modal sheet trigger | `IMPLEMENTED_EVIDENCED` |
| `FixNotificationBell` | `fix_notification_bell.dart` | 130 | Bell icon, badge count pill, shake animation on new unread notification | `IMPLEMENTED_EVIDENCED` |
| `FixOtpInputSheet` | `fix_otp_input_sheet.dart` | 185 | 4-cell numeric pin sheet, autofocus, auto-submit on completion | `IMPLEMENTED_EVIDENCED` |
| `FixPaymentCheckoutSheet`| `fix_payment_checkout_sheet.dart`| 790 | Multi-method payment sheet, simulated success timer, price breakdown | `MOCKED_SIMULATED` (GAP-41) |
| `FixJobProofDialog` | `fix_job_proof_dialog.dart` | 680 | Before/after camera capture, review viewer, simulated test photos button | `PARTIAL` (GAP-19, GAP-40) |
| `FixPriceBreakdownCard` | `fix_price_breakdown_card.dart` | 215 | Subtotal, GST 18%, discount row, total amount minor | `IMPLEMENTED_EVIDENCED` |
| `FixSchedulePicker` | `fix_schedule_picker.dart` | 620 | Calendar date selector, morning/afternoon/evening slot grid chips | `IMPLEMENTED_EVIDENCED` |
| `FixRescheduleSheet` | `fix_reschedule_sheet.dart` | 290 | Bottom sheet to pick new date slot for existing booking | `IMPLEMENTED_EVIDENCED` |
| `FixSosVortexButton` | `fix_sos_vortex_button.dart` | 175 | Circular pulse button, 3-second hold listener with haptic feedback | `IMPLEMENTED_EVIDENCED` |
| `FixBanner` | `fix_banner.dart` | 95 | Top-anchored toast banner, optional action button | `PARTIAL` (Live no-op button, GAP-46) |
| `FixSlideToConfirm` | `fix_slide_to_confirm.dart` | 165 | Draggable thumb slider, threshold trigger | `IMPLEMENTED_UNVERIFIED` (Unreferenced, GAP-53) |
| `FixStarRatingBurst` | `fix_star_rating_burst.dart` | 130 | Particle burst on 5-star rating | `IMPLEMENTED_UNVERIFIED` (Unreferenced, GAP-53) |
| `Fix3DSpatialBeacon` | `fix_3d_spatial_beacon.dart` | 210 | 3D matrix transformation beacon | `IMPLEMENTED_UNVERIFIED` (Unreferenced, GAP-53) |
| `FixAudioWaveform` | `fix_audio_waveform.dart` | 110 | Animated frequency bars | `IMPLEMENTED_UNVERIFIED` (Unreferenced, GAP-53) |
| `EtaProgressRing` | `fix_eta_ring.dart` | 95 | Circular arrival countdown ring | `IMPLEMENTED_UNVERIFIED` (Unreferenced, GAP-53) |
| `FixServiceCardGallery` | `fix_service_card_gallery.dart` | 115 | Demo gallery with fake services | `DEAD_UNREACHABLE` (GAP-52) |
| `FixProviderCardGallery` | `fix_provider_card_gallery.dart`| 145 | Demo gallery with fake providers | `DEAD_UNREACHABLE` (GAP-52) |

<!-- RECONCILIATION-APPENDIX -->

## Current dispositions 2026-10-21

The following source-backed dispositions supersede the corresponding historical claims above. See the central register for validation limits and remaining priorities. Reused IDs include separate variant rows.

| ID | Current disposition | Original claim / current evidence | Source references |
|---|---|---|---|
| GAP-03 | **FIXED_IN_SOURCE** | Completion cancel dialog continues anyway<br>**Current:** Guard uses \|\| and returns when cancelled/unmounted. | [mobile/lib/features/provider/provider_active_job_cockpit_screen.dart:180](../mobile/lib/features/provider/provider_active_job_cockpit_screen.dart#L180) |
| GAP-05 | **FIXED_IN_SOURCE** | Trust route lacks role checks; inventory extends claim to bookings/providers.<br>**Current:** Trust rejects non-trust roles; bookings/providers also gate roles. Backend still enforces access. Old test.fixme assertion is active now, but stale explanatory comment remains. | [admin/src/app/trust/page.tsx:40](../admin/src/app/trust/page.tsx#L40); [admin/src/app/bookings/page.tsx:24](../admin/src/app/bookings/page.tsx#L24); [admin/src/app/providers/page.tsx:15](../admin/src/app/providers/page.tsx#L15); [admin/src/app/trust/page.test.tsx:97](../admin/src/app/trust/page.test.tsx#L97); [e2e/tests/admin-operations.spec.ts:148](../e2e/tests/admin-operations.spec.ts#L148) |
| GAP-06 | **FIXED_IN_SOURCE** | Auditor support navigation and service mutation forms conflict with backend permissions.<br>**Current:** Support nav/page excludes auditor; services checks canMutateServices to hide mutation UI. Unconditional header notifications still links support for every role; this is a distinct residual UX issue. | [admin/src/components/admin-shell.tsx:10](../admin/src/components/admin-shell.tsx#L10); [admin/src/app/support/page.tsx:21](../admin/src/app/support/page.tsx#L21); [admin/src/app/services/page.tsx:26](../admin/src/app/services/page.tsx#L26); [admin/src/auth/roles.ts:114](../admin/src/auth/roles.ts#L114); [admin/src/components/admin-shell.tsx:158](../admin/src/components/admin-shell.tsx#L158); [backend/src/common/authorization/permission-policies.ts:492](../backend/src/common/authorization/permission-policies.ts#L492) |
| GAP-07 | **PARTIAL** | Guarantee dropdown allows illegal transitions, leading to backend 409 crash.<br>**Current:** UI transition table and terminal rendering now exist. Claimed backend invalid-transition 409 is unsupported: updateStatus assigns any valid DTO enum without lifecycle validation. Thus UI gap fixed, backend invariant remains absent. | [admin/src/app/guarantees/[id]/page.tsx:15](../admin/src/app/guarantees/[id]/page.tsx#L15); [admin/src/app/guarantees/[id]/page.tsx:138](../admin/src/app/guarantees/[id]/page.tsx#L138); [backend/src/guarantees/guarantees.service.ts:128](../backend/src/guarantees/guarantees.service.ts#L128); [admin/src/app/guarantees/[id]/page.test.ts:4](../admin/src/app/guarantees/[id]/page.test.ts#L4) |
| GAP-17 | **FIXED_IN_SOURCE** | Complaint dossier renders blank name/email due to UserDetail contract mismatch.<br>**Current:** Canonical user fields are optional, operations getUser reexports users implementation, and dossier renders explicit user-ID / identity-redacted fallbacks. Backend still intentionally projects minimal PII; unavailable personal fields are not by themselves defects. | [admin/src/features/users/types.ts:1](../admin/src/features/users/types.ts#L1); [admin/src/features/operations/api.ts:19](../admin/src/features/operations/api.ts#L19); [admin/src/app/support/[complaintId]/page.tsx:215](../admin/src/app/support/[complaintId]/page.tsx#L215); [admin/src/app/support/[complaintId]/page.tsx:237](../admin/src/app/support/[complaintId]/page.tsx#L237); [backend/src/admin/admin-management.service.ts:153](../backend/src/admin/admin-management.service.ts#L153) |
| GAP-19 | **FIXED_IN_SOURCE** | Simulated proof images and in-memory repository<br>**Current:** Capture failure reports error; upload callback mandatory; legacy repository removed. | [mobile/lib/design_system/fix_job_proof_dialog.dart:119](../mobile/lib/design_system/fix_job_proof_dialog.dart#L119); [mobile/lib/design_system/fix_job_proof_dialog.dart:134](../mobile/lib/design_system/fix_job_proof_dialog.dart#L134); [mobile/lib/features/provider/provider_active_job_cockpit_screen.dart:172](../mobile/lib/features/provider/provider_active_job_cockpit_screen.dart#L172); [mobile/lib/features/bookings/job_proof_service.dart:36](../mobile/lib/features/bookings/job_proof_service.dart#L36) |
| GAP-20 | **FIXED_IN_SOURCE** | Bookings emergency banner matches description substring.<br>**Current:** Now counts booking.isEmergency true; backend derives flag from emergency category IDs. | [admin/src/app/bookings/page.tsx:31](../admin/src/app/bookings/page.tsx#L31); [backend/src/admin/admin-operations.service.ts:75](../backend/src/admin/admin-operations.service.ts#L75); [backend/src/admin/admin-operations.service.ts:161](../backend/src/admin/admin-operations.service.ts#L161) |
| GAP-21 | **FIXED_IN_SOURCE** | Guarantee server actions throw on API failure and trigger error.tsx.<br>**Current:** Both status/re-service mutations redirect with error query and page renders alert; successful actions revalidate and redirect. | [admin/src/app/guarantees/[id]/page.tsx:52](../admin/src/app/guarantees/[id]/page.tsx#L52); [admin/src/app/guarantees/[id]/page.tsx:63](../admin/src/app/guarantees/[id]/page.tsx#L63); [admin/src/app/guarantees/[id]/page.tsx:91](../admin/src/app/guarantees/[id]/page.tsx#L91) |
| GAP-22 | **FIXED_IN_SOURCE** | Native maps launcher no-op<br>**Current:** Native helper uses url_launcher external application. | [mobile/lib/features/location/url_launcher_stub.dart:1](../mobile/lib/features/location/url_launcher_stub.dart#L1) |
| GAP-23 | **PARTIAL** | Seven admin pages load full unpaginated tables; search queries run sequentially.<br>**Current:** Search uses Promise.all; complaints/trust have server offset pagination, provider/users/bookings cursor pagination. Admin services still loads all categories then slices; guarantees backend caps default 50 without continuation and UI paginates only fetched slice. Search locally filters default first 20 complaints / 50 claims, so older matching records remain absent. | [admin/src/app/search/page.tsx:35](../admin/src/app/search/page.tsx#L35); [admin/src/app/search/page.tsx:64](../admin/src/app/search/page.tsx#L64); [admin/src/app/search/page.tsx:79](../admin/src/app/search/page.tsx#L79); [admin/src/app/search/page.tsx:91](../admin/src/app/search/page.tsx#L91); [admin/src/app/services/page.tsx:27](../admin/src/app/services/page.tsx#L27); [backend/src/admin/admin-operations.service.ts:29](../backend/src/admin/admin-operations.service.ts#L29); [admin/src/app/guarantees/page.tsx:27](../admin/src/app/guarantees/page.tsx#L27); [backend/src/guarantees/guarantees.service.ts:103](../backend/src/guarantees/guarantees.service.ts#L103); [backend/src/common/list-pagination.dto.ts:41](../backend/src/common/list-pagination.dto.ts#L41) |
| GAP-24 | **FIXED_IN_SOURCE** | Date strip never filters jobs<br>**Current:** Selected date filters both assigned/history lists. | [mobile/lib/features/provider/provider_jobs_screen.dart:66](../mobile/lib/features/provider/provider_jobs_screen.dart#L66); [mobile/lib/features/provider/provider_jobs_screen.dart:78](../mobile/lib/features/provider/provider_jobs_screen.dart#L78) |
| GAP-25 | **FIXED_IN_SOURCE** | Bookings reads nextCursor without Load More control.<br>**Current:** Load more link passes cursor and current filters. | [admin/src/app/bookings/page.tsx:128](../admin/src/app/bookings/page.tsx#L128) |
| GAP-27 | **FIXED_IN_SOURCE** | Bookings table has no dossier navigation.<br>**Current:** Booking ID is now Link to detail. | [admin/src/app/bookings/page.tsx:108](../admin/src/app/bookings/page.tsx#L108) |
| GAP-28 | **FIXED_IN_SOURCE** | Providers/support permanent placeholder panes consume 40% layout.<br>**Current:** Queue pages use real empty/list state and navigation controls; literal placeholder panes absent. | [admin/src/app/providers/page.tsx:86](../admin/src/app/providers/page.tsx#L86); [admin/src/app/providers/page.tsx:128](../admin/src/app/providers/page.tsx#L128); [admin/src/app/support/page.tsx:114](../admin/src/app/support/page.tsx#L114); [admin/src/app/support/page.tsx:122](../admin/src/app/support/page.tsx#L122); [admin/src/app/support/page.tsx:162](../admin/src/app/support/page.tsx#L162) |
| GAP-30 | **FIXED_IN_SOURCE** | Hardcoded customer tracking avatar<br>**Current:** Tracking renders person icons. | [mobile/lib/features/tracking/booking_tracking_screen.dart:116](../mobile/lib/features/tracking/booking_tracking_screen.dart#L116) |
| GAP-39 | **FIXED_IN_SOURCE** | Dead Android audio_tone/voice_stream MethodChannels<br>**Current:** Only navigation MethodChannel remains; historical audio/voice channels absent. | [mobile/android/app/src/main/kotlin/com/fixnow/fixnow_mobile/MainActivity.kt:16](../mobile/android/app/src/main/kotlin/com/fixnow/fixnow_mobile/MainActivity.kt#L16) |
| GAP-40 | **DUPLICATE** | Fabricated job proof<br>**Current:** Same historical issue as GAP-19; fixed in source. | [mobile/lib/design_system/fix_job_proof_dialog.dart:134](../mobile/lib/design_system/fix_job_proof_dialog.dart#L134) |
| GAP-41 | **FIXED_IN_SOURCE** | Missing payment callback fabricates success<br>**Current:** Missing callback throws StateError. Only caller is development-gated checkout with callback. | [mobile/lib/design_system/fix_payment_checkout_sheet.dart:145](../mobile/lib/design_system/fix_payment_checkout_sheet.dart#L145); [mobile/lib/features/payments/invoice_screen.dart:216](../mobile/lib/features/payments/invoice_screen.dart#L216) |
| GAP-42 | **PARTIAL** | Fake GSTIN, conflicting legal addresses, broken QR URL<br>**Current:** UI/PDF use shared compile-time configuration, removing duplicated conflicting addresses. The default GSTIN and verification URL remain placeholders with no production-specific required override check in AppEnvironment. Production configuration and URL availability were not inspected; the old specific 404 claim is unverified. | [mobile/lib/features/payments/fix_pdf_invoice_builder.dart:14](../mobile/lib/features/payments/fix_pdf_invoice_builder.dart#L14); [mobile/lib/features/payments/invoice_screen.dart:300](../mobile/lib/features/payments/invoice_screen.dart#L300); [mobile/lib/config/app_environment.dart:19](../mobile/lib/config/app_environment.dart#L19); [mobile/lib/config/app_environment.dart:35](../mobile/lib/config/app_environment.dart#L35) |
| GAP-43 | **PARTIAL** | Notification deletes never persist/no backend endpoint<br>**Current:** Original no-backend/local-only assertion is fixed: owned DELETE endpoints and real requests exist. The repository still marks items deleted locally before an unawaited request, ignores token errors, and does not validate response success or roll back the local dismissal. Successful persistence and reload behavior were not established by a live test. | [mobile/lib/features/notifications/notification_repository.dart:112](../mobile/lib/features/notifications/notification_repository.dart#L112); [mobile/lib/features/notifications/notification_repository.dart:113](../mobile/lib/features/notifications/notification_repository.dart#L113); [backend/src/notifications/domain/inbox.controller.ts:93](../backend/src/notifications/domain/inbox.controller.ts#L93); [backend/src/notifications/domain/inbox.controller.ts:111](../backend/src/notifications/domain/inbox.controller.ts#L111) |
| GAP-45 | **PARTIAL** | Five inert controls<br>**Current:** Referral and biometric placeholder controls removed (no matching identifiers in files). Push category switches still local state. Help callback now dispatches for existing complaint, honestly unavailable otherwise. Payment Methods row opens information sheet. | [mobile/lib/notifications/push_settings_card.dart:265](../mobile/lib/notifications/push_settings_card.dart#L265); [mobile/lib/features/support/customer_help_screen.dart:883](../mobile/lib/features/support/customer_help_screen.dart#L883); [mobile/lib/features/profile/customer_profile_screen.dart:411](../mobile/lib/features/profile/customer_profile_screen.dart#L411) |
| GAP-46 | **FIXED_IN_SOURCE** | Banner creates no-op action<br>**Current:** Action omitted unless label and callback both provided. | [mobile/lib/design_system/fix_banner.dart:38](../mobile/lib/design_system/fix_banner.dart#L38) |
| GAP-48 | **PARTIAL** | Fake wallet balance and conflicting cancellation fee copy<br>**Current:** Fake numerical wallet balance removed; generic wallet method remains in development-gated sheet. Cancellation dialog still says full refund and fee once en route; tracking says fee after free window. Actual fee collection/policy agreement needs backend/domain reconciliation. | [mobile/lib/design_system/fix_payment_checkout_sheet.dart:591](../mobile/lib/design_system/fix_payment_checkout_sheet.dart#L591); [mobile/lib/features/bookings/cancellation_dialog.dart:77](../mobile/lib/features/bookings/cancellation_dialog.dart#L77); [mobile/lib/features/tracking/booking_tracking_screen.dart:1022](../mobile/lib/features/tracking/booking_tracking_screen.dart#L1022); [mobile/lib/features/payments/invoice_screen.dart:216](../mobile/lib/features/payments/invoice_screen.dart#L216) |
| GAP-50 | **FIXED_IN_SOURCE** | 22 unreachable mobile files including six obsolete screens<br>**Current:** All six named obsolete screen sources absent. Current import graph has 10 unreferenced DS sources, voice_assistance, call_screen plus conditional-import url_launcher_web false positive; historical 22 count unsupported. Residuals tracked GAP-53/51. | [mobile/lib/main.dart:2](../mobile/lib/main.dart#L2); [mobile/lib/features/call/call_screen.dart:14](../mobile/lib/features/call/call_screen.dart#L14) |
| GAP-51 | **PARTIAL** | HttpCallRepository never instantiated/entire calling unwired<br>**Current:** Repository/controller instantiated, buttons start API call then show snackbar. No navigation/import to CallScreen. Screen hangup only local; controller does not expose accept/reject/hangup. Do not claim backend 100% complete or actual audio connected from this source trace. | [mobile/lib/app/app.dart:426](../mobile/lib/app/app.dart#L426); [mobile/lib/app/app.dart:1333](../mobile/lib/app/app.dart#L1333); [mobile/lib/app/app.dart:1363](../mobile/lib/app/app.dart#L1363); [mobile/lib/features/call/call_screen.dart:90](../mobile/lib/features/call/call_screen.dart#L90); [mobile/lib/features/call/call_controller.dart:35](../mobile/lib/features/call/call_controller.dart#L35) |
| GAP-52 | **FIXED_IN_SOURCE** | Demo galleries fake data in binary<br>**Current:** Both named gallery sources absent, no production references. Original compiled-binary claim unsupported without build artifact inspection. | [mobile/lib/main.dart:2](../mobile/lib/main.dart#L2) |
| GAP-53 | **PARTIAL** | 33 unused DS widgets compiled into binary<br>**Current:** Read-only import graph finds 10 unreachable DS sources: fix_3d_spatial_beacon,fix_3d_tilt_card,fix_audio_waveform,fix_eta_ring,fix_jelly_squish_button,fix_journey_progress_line,fix_provider_card,fix_slide_to_confirm,fix_sos_vortex_button,fix_star_rating_burst. Source deadness retained; binary inclusion cannot be concluded due to tree shaking. Historical count stale. | [mobile/lib/design_system/fix_3d_spatial_beacon.dart:9](../mobile/lib/design_system/fix_3d_spatial_beacon.dart#L9); [mobile/lib/design_system/fix_slide_to_confirm.dart:11](../mobile/lib/design_system/fix_slide_to_confirm.dart#L11) |
| GAP-54 | **FIXED_IN_SOURCE** | Analytics/users/user-detail routes orphaned.<br>**Current:** Navigation links analytics/users, user table links detail. Prior inventory itself acknowledged guarantee-to-user links, so absolute zero inbound claim was inaccurate. | [admin/src/components/admin-shell.tsx:14](../admin/src/components/admin-shell.tsx#L14); [admin/src/components/admin-shell.tsx:15](../admin/src/components/admin-shell.tsx#L15); [admin/src/app/users/page.tsx:115](../admin/src/app/users/page.tsx#L115); [admin/src/app/guarantees/[id]/page.tsx:198](../admin/src/app/guarantees/[id]/page.tsx#L198) |
| GAP-56 | **DUPLICATE** | Clear All in-memory only<br>**Current:** Same as GAP-43; server endpoint and dispatch now exist. | [mobile/lib/features/notifications/notification_repository.dart:113](../mobile/lib/features/notifications/notification_repository.dart#L113) |
| GAP-57 | **FIXED_IN_SOURCE** | No admin UI exists for review/photo moderation.<br>**Current:** Trust page provides review/photo UUID moderation forms wired via server actions to backend endpoints. Moderation browsing queue is still absent; current forms require externally known IDs. Original zero-UI claim fixed; richer queue is scope distinction. | [admin/src/app/trust/page.tsx:194](../admin/src/app/trust/page.tsx#L194); [admin/src/app/trust/page.tsx:223](../admin/src/app/trust/page.tsx#L223); [admin/src/features/trust/actions.ts:18](../admin/src/features/trust/actions.ts#L18); [admin/src/features/trust/actions.ts:31](../admin/src/features/trust/actions.ts#L31); [admin/src/features/trust/api.ts:22](../admin/src/features/trust/api.ts#L22) |
| GAP-58 | **DUPLICATE** | Guarantee missing client transition table.<br>**Current:** Same claim as GAP-07; UI fixed, backend lifecycle guard absent. Do not count twice. | [admin/src/app/guarantees/[id]/page.tsx:15](../admin/src/app/guarantees/[id]/page.tsx#L15); [backend/src/guarantees/guarantees.service.ts:128](../backend/src/guarantees/guarantees.service.ts#L128) |
| GAP-68 | **DUPLICATE** | Cosmetic provider date strip<br>**Current:** Same issue as GAP-24; fixed. | [mobile/lib/features/provider/provider_jobs_screen.dart:78](../mobile/lib/features/provider/provider_jobs_screen.dart#L78) |
| GAP-73 | **FIXED_IN_SOURCE** | Two conflicting getUser client implementations/types.<br>**Current:** Operations reexports canonical getUser; old operations UserDetail optional-field alias remains unused but no competing request implementation. | [admin/src/features/operations/api.ts:19](../admin/src/features/operations/api.ts#L19); [admin/src/features/users/api.ts:11](../admin/src/features/users/api.ts#L11); [admin/src/features/users/types.ts:1](../admin/src/features/users/types.ts#L1); [admin/src/features/operations/types.ts:16](../admin/src/features/operations/types.ts#L16) |
| GAP-87 | **PARTIAL** | 12/18 routes have zero automated coverage.<br>**Current:** Numerical absolute claim stale/unsupported: dashboard/login/bookings/users/unauthorized have E2E route coverage; guarantee detail has lifecycle unit tests; trust role regression test exists. Several dossier/CRUD/routes still lack dedicated behavior coverage. Unit-helper coverage is not full rendered-page or persistence coverage. Parent runs current admin tests; no tests rerun by this subagent. Historical inventory cites management-api.test.ts and features/search/search.test.ts, neither exists in current admin/src; do not treat those as present tests. | [audit_reports/FIXNOW_TEST_COVERAGE_INVENTORY.md:104](../audit_reports/FIXNOW_TEST_COVERAGE_INVENTORY.md#L104); [e2e/tests/admin-access.spec.ts:81](../e2e/tests/admin-access.spec.ts#L81); [e2e/tests/admin-access.spec.ts:97](../e2e/tests/admin-access.spec.ts#L97); [e2e/tests/admin-operations.spec.ts:171](../e2e/tests/admin-operations.spec.ts#L171); [e2e/tests/admin-operations.spec.ts:171](../e2e/tests/admin-operations.spec.ts#L171); [admin/src/app/guarantees/[id]/page.test.ts:4](../admin/src/app/guarantees/[id]/page.test.ts#L4); [admin/src/app/trust/page.test.tsx:97](../admin/src/app/trust/page.test.tsx#L97) |
| GAP-19/API-trust-pagination | **FIXED_IN_SOURCE** | API inventory uses GAP-19 for unpaginated trust signals<br>**Current:** ID collision with mobile fabricated job proof. Trust endpoint now accepts limit/offset; service clamps take to 1..100 and applies skip. Status filtering remains a separate UI defect covered by parent. | [audit_reports/FIXNOW_API_AND_BACKEND_INVENTORY.md:283](../audit_reports/FIXNOW_API_AND_BACKEND_INVENTORY.md#L283); [backend/src/trust/trust-admin.controller.ts:27](../backend/src/trust/trust-admin.controller.ts#L27); [backend/src/trust/trust.service.ts:282](../backend/src/trust/trust.service.ts#L282) |
| GAP-25/DB-audit-cascade | **DUPLICATE** | Database inventory uses GAP-25 for auth audit CASCADE<br>**Current:** Database inventory uses GAP-25 for canonical GAP-10. Later migration implements SET NULL; deployment and live constraints were not checked. | [audit_reports/FIXNOW_DATABASE_AND_INTEGRATIONS.md:126](../audit_reports/FIXNOW_DATABASE_AND_INTEGRATIONS.md#L126); [backend/migrations/1789750500000-Phase2IntegrityAndConstraints.ts:27](../backend/migrations/1789750500000-Phase2IntegrityAndConstraints.ts#L27) |
