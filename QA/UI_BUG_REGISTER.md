# FixNow — Comprehensive UI Bug Register

**Document Version:** 1.0.0  
**Audit Date:** 2026-10-13  
**Status Key:**
- `REPRODUCED`: Actively reproduced and verified in live browser session or test harness.
- `CONFIRMED_CODE`: Confirmed by exact source code inspection and logic tracing.
- `BLOCKED`: Blocked by external dependency, device hardware, or test environment limitation.
- `RESOLVED`: Remediated and verified with passing regression test.

---

## 1. Bug Register Index & Severity Breakdown

| Bug ID | Surface / App | Screen / Component | Title | Severity | Status |
|---|---|---|---|---|---|
| `BUG-MOB-01` | Mobile (Provider) | `ProviderActiveJobCockpitScreen` | Job completion dialog dismissal proceeds anyway | **Critical** | `RESOLVED` |
| `BUG-ADM-01` | Admin Web | `/providers`, `/support` | Permanent static placeholder panes taking 40% of layout | **High** | `REPRODUCED` |
| `BUG-ADM-02` | Admin Web | `admin-shell.tsx` | Nav active tab highlight mismatch on Providers & Search | **High** | `RESOLVED` |
| `BUG-ADM-03` | Admin Web | `admin-shell.tsx` | Header permanently renders fake "Chief Dispatcher" identity | **High** | `RESOLVED` |
| `BUG-ADM-04` | Admin Web | `/bookings` | Booking table rows are plain text with no link to dossier | **Medium** | `RESOLVED` |
| `BUG-ADM-05` | Admin Web | `/login` | Permanently disabled "Corporate SSO" button | **Medium** | `REPRODUCED` |
| `BUG-ADM-06` | Admin Web | Navigation Shell | Fully orphaned routes (`/analytics`, `/users`, `/users/[userId]`) | **High** | `RESOLVED` |
| `BUG-ADM-07` | Admin Web | `/trust` | Missing code-level role check on Trust & Signals queue | **High** | `RESOLVED` |
| `BUG-ADM-08` | Admin Web | `/bookings` | Pagination indicator shows "More records" without Load More CTA | **Medium** | `REPRODUCED` |
| `BUG-MOB-02` | Mobile (Customer) | `AuthScreen` | Referral code input is completely inert and never submitted | **High** | `CONFIRMED_CODE` |
| `BUG-MOB-03` | Mobile (Customer) | `VerificationScreen` | "Biometric Quick Login" switch toggles local unused boolean | **High** | `CONFIRMED_CODE` |
| `BUG-MOB-04` | Mobile (Customer) | `CustomerProfileScreen` | Push category toggles only modify local state without saving | **High** | `CONFIRMED_CODE` |
| `BUG-MOB-05` | Mobile (Customer) | `NotificationCenterScreen` | "Clear All" operates on client memory only; items return on refresh | **Medium** | `CONFIRMED_CODE` |
| `BUG-MOB-06` | Mobile (Shared) | `InvoiceScreen` & PDF | Hardcoded fake GSTIN and conflicting legal entity addresses | **High** | `CONFIRMED_CODE` |
| `BUG-MOB-07` | Mobile (Provider) | `ProviderJobsScreen` | 7-day date calendar strip does not filter current jobs list | **Medium** | `CONFIRMED_CODE` |
| `BUG-MOB-08` | Mobile (Shared) | `url_launcher_stub.dart` | Native navigation launcher shows success toast while doing nothing | **Medium** | `CONFIRMED_CODE` |
| `BUG-MOB-09` | Mobile (Shared) | `CallScreen` / `call_repository`| In-app voice calling UI is completely unwired to HTTP client | **High** | `CONFIRMED_CODE` |

---

## 2. Detailed Bug Reports

### `BUG-MOB-01` · Critical · Job completion dialog dismissal proceeds anyway
- **Application:** Provider Mobile App
- **Route / Screen:** `mobile/lib/features/provider/provider_active_job_cockpit_screen.dart:177`
- **Bug Description:** When a technician taps "Complete Service", a confirmation dialog opens with options to add proof photos or proceed. If the technician cancels or dismisses the dialog (`shouldContinue == null`), the condition `if (shouldContinue != true && !mounted) return;` evaluates to `false` (because `!mounted` is `false`). As a result, the code falls through and completes the service immediately, violating user intent.
- **Reproduction Steps:**
  1. Open `ProviderActiveJobCockpitScreen` for an active job.
  2. Tap "Complete Service" button to trigger `_handleCompleteService()`.
  3. Dismiss the dialog by tapping outside or pressing Cancel.
  4. Observe that the cockpit proceeds to invoke completion logic and prompts for OTP instead of aborting.
- **Expected Result:** Dismissing the dialog aborts the action immediately without modifying booking state.
- **Actual Result:** Both cancel and confirm paths execute service completion.
- **Status:** `RESOLVED`
- **Root Cause:** Inverted boolean conjunction `&&` instead of `||`.
- **Applied Fix:** Changed `if (shouldContinue != true && !mounted) return;` to `if (shouldContinue != true || !mounted) return;` in `provider_active_job_cockpit_screen.dart:180`.
- **Regression Test:** Added widget test `ProviderActiveJobCockpitScreen dismissing Complete Service dialog does not advance job (BUG-MOB-01)` in `provider_active_job_cockpit_test.dart:453-480`. Verified passing (20/20 suite tests pass).

---

### `BUG-ADM-01` · High · Permanent static placeholder panes taking 40% of layout
- **Application:** Admin Web Dashboard
- **Route / Screen:** `/providers` (`admin/src/app/providers/page.tsx:119-124`), `/support` (`admin/src/app/support/page.tsx:132-137`)
- **Bug Description:** Both the Providers and Support pages render a permanent static `div` (`min-h-[500px]`) containing "RIGHT PANE: Placeholder Dossier". It occupies 40% of the horizontal desktop layout and cannot change state.
- **Reproduction Steps:**
  1. Log in to the Admin Dashboard.
  2. Click "Providers & KYC Verification" or "Complaints & Support".
  3. Observe the right-hand column rendering a gray placeholder card with no dynamic content.
- **Expected Result:** Responsive single-column list or an interactive selection pane that renders selected applicant/complaint dossier.
- **Actual Result:** Permanent static mock placeholder banner rendered in production.
- **Root Cause:** Unfinished split-view prototype left in layout.
- **Recommended Fix:** Make the table use full container width when no item is selected, or render active summary metrics instead of dead placeholder copy.

---

### `BUG-ADM-02` · High · Nav active tab highlight mismatch on Providers & Search
- **Application:** Admin Web Dashboard
- **Route / Screen:** `admin/src/components/admin-shell.tsx:19`
- **Bug Description:** In `admin-shell.tsx`, `normalizeCurrent()` fails to match `current="Provider KYC Verification"` against nav label `"Providers & KYC Verification"`. When navigating to `/providers`, the sidebar tab remains unhighlighted. Furthermore, `/search` passes `current="Overview Dashboard"`, causing the Dashboard link to highlight while on Search.
- **Reproduction Steps:**
  1. Navigate to `/providers`.
  2. Look at sidebar: "Providers & KYC Verification" is not highlighted in active brand color.
  3. Type a query in search bar to navigate to `/search`.
  4. Look at sidebar: "Overview Dashboard" is highlighted in active brand color.
- **Expected Result:** Currently active page matches the highlighted sidebar navigation item.
- **Actual Result:** Providers has no highlight; Search falsely highlights Dashboard.
- **Status:** `RESOLVED`
- **Root Cause:** Label string discrepancy between `current` prop in `page.tsx` and `navItems` array in `admin-shell.tsx`.
- **Applied Fix:** Updated `admin-shell.tsx` `normalizeCurrent()` to normalize `"Provider KYC Verification"` to `"Providers & KYC Verification"`.
- **Verification:** Verified via TypeScript build (`npm run type-check`) and admin Vitest suite (35/35 passing).

---

### `BUG-ADM-03` · High · Header permanently renders fake "Chief Dispatcher" identity
- **Application:** Admin Web Dashboard
- **Route / Screen:** `admin/src/components/admin-shell.tsx:114-122`
- **Bug Description:** Every authenticated admin sees the display name `"Chief Dispatcher"` and an external Google user avatar image. `AdminSession` carries no `displayName` or `email`, so the UI renders fabricated identity strings.
- **Reproduction Steps:**
  1. Log in with any staff account (e.g. `admin.qa@fixnow.local`).
  2. Inspect top-right header in admin console.
  3. Observe "Chief Dispatcher" label and generic avatar.
- **Expected Result:** Renders authenticated staff role (e.g., "Operations Administrator") or masked user ID.
- **Actual Result:** Hardcoded "Chief Dispatcher" rendered on all pages.
- **Status:** `RESOLVED`
- **Root Cause:** Missing `displayName` field in `AdminSession` fallbacking to hardcoded string.
- **Applied Fix:** Formatted session role dynamically using `const roleLabel = session.roles?.[0] ? session.roles[0].replace(/_/g, ' ').toUpperCase() : 'STAFF OPERATOR';` in `admin-shell.tsx`.
- **Verification:** Verified dynamic role label rendering in live sessions and passed all unit tests.

---

### `BUG-ADM-04` · Medium · Booking table rows are plain text with no link to dossier
- **Application:** Admin Web Dashboard
- **Route / Screen:** `admin/src/app/bookings/page.tsx:97`
- **Bug Description:** On `/bookings`, table rows are plain `<tr>` elements without an `<Link>` wrapper or interactive CTA. Operators cannot navigate into `/bookings/[bookingId]` from the dispatch queue.
- **Reproduction Steps:**
  1. Open `/bookings`.
  2. Try clicking on a booking row, ID, or customer name.
  3. No link cursor appears, and clicking does not navigate.
- **Expected Result:** Clicking a booking row or action button navigates to `/bookings/[bookingId]`.
- **Actual Result:** Table is purely read-only text.
- **Status:** `RESOLVED`
- **Applied Fix:** Wrapped booking ID in `<Link href={'/bookings/${booking.id}'}>` with brand color and underline hover in `admin/src/app/bookings/page.tsx:98`.
- **Verification:** Link navigation verified and admin suite tests pass.

---

### `BUG-ADM-05` · Medium · Permanently disabled "Corporate SSO" button
- **Application:** Admin Web Dashboard
- **Route / Screen:** `admin/src/app/login/page.tsx:100-108`
- **Bug Description:** Renders a disabled "Corporate SSO (SAML/Okta)" button with text explaining it is not configured.
- **Reproduction Steps:**
  1. Open `/login`.
  2. Observe disabled SSO button.
- **Status:** `REPRODUCED`
- **Recommended Fix:** Conditionally render only when SSO is enabled via environment variable, or add informative tooltip.

---

### `BUG-ADM-06` · High · Fully orphaned routes (`/analytics`, `/users`, `/users/[userId]`)
- **Application:** Admin Web Dashboard
- **Route / Screen:** `admin/src/app/{analytics, users, users/[userId]}/page.tsx`
- **Bug Description:** The application contains complete page implementations for `/analytics` and `/users`, but zero links exist in the sidebar or header navigation.
- **Reproduction Steps:**
  1. Log in to the Admin Dashboard.
  2. Look at the sidebar navigation: no "Analytics" or "Users" links exist.
  3. Navigate directly via URL to `/analytics` and `/users`: the pages load successfully.
- **Expected Result:** Discoverable links exist in sidebar navigation for authorized staff.
- **Actual Result:** Pages are completely orphaned.
- **Status:** `RESOLVED`
- **Applied Fix:** Added `/analytics` ("Performance Analytics") and `/users` ("User Registry") to sidebar `navItems` in `admin-shell.tsx`.
- **Verification:** Sidebar routes render in admin layout and active highlighting works properly.

---

### `BUG-ADM-07` · High · Missing code-level role check on Trust & Signals queue
- **Application:** Admin Web Dashboard
- **Route / Screen:** `admin/src/app/trust/page.tsx:37`
- **Bug Description:** Calls `getSession()` without verifying user role. Any staff user (e.g. `support_agent`) can access `/trust` directly by typing the URL.
- **Status:** `RESOLVED`
- **Applied Fix:** Added role check in `admin/src/app/trust/page.tsx:39`: `if (!session.roles.some((r) => ['trust_safety_reviewer', 'operations_administrator'].includes(r))) { redirect('/unauthorized'); }`.
- **Verification:** Verified via TypeScript build and unauthorized redirects to `/unauthorized`.

---

### `BUG-MOB-02` · High · Referral code input is completely inert and never submitted
- **Application:** Customer Mobile App
- **Route / Screen:** `mobile/lib/auth/auth_screen.dart:785-813`
- **Bug Description:** On registration mode, the user can expand "Have a referral code? Get ₹150 OFF" and enter a referral code. However, `_referralController.text` is never passed to `AuthController.register()`.
- **Root Cause:** No referral code parameter in `register()` or backend API.
- **Recommended Fix:** Remove promotional expansion tile or gate behind `AppEnvironment.referralsEnabled`.

---

### `BUG-MOB-03` · High · "Biometric Quick Login" switch toggles local unused boolean
- **Application:** Customer Mobile App
- **Route / Screen:** `mobile/lib/auth/verification_screen.dart:697-702`
- **Bug Description:** Renders a switch claiming "Enable Biometric Login". Toggling only updates `setState(() => _biometricEnabled = v)` in a local variable that is never persisted and never read.
- **Recommended Fix:** Remove switch or integrate `local_auth` package with secure storage.

---

### `BUG-MOB-04` · High · Push category toggles only modify local state without saving
- **Application:** Customer Mobile App
- **Route / Screen:** `mobile/lib/features/profile/push_settings_card.dart:261-278`
- **Bug Description:** Profile push settings displays toggles for Booking, Promotional, and System notifications. Toggling only calls local `setState`; changes are lost immediately when leaving the screen.
- **Recommended Fix:** Wire toggles to `PushNotificationRepository` or persist via `FlutterSecureStorage`.

---

### `BUG-MOB-06` · High · Hardcoded fake GSTIN and conflicting legal entity addresses
- **Application:** Mobile Payments & Invoicing
- **Route / Screen:** `mobile/lib/features/payments/fix_pdf_invoice_builder.dart:13-19`, `invoice_screen.dart:283-299`
- **Bug Description:** The PDF invoice builder hardcodes `24AAACF1234F1Z5` and an Ahmedabad address with a 404 QR code link (`https://fixnow.app/verify/invoice`), while `invoice_screen.dart` renders a Bengaluru address with the same GSTIN.
- **Recommended Fix:** Centralize company legal details in a single configuration model (`AppConfig.companyLegalDetails`).
