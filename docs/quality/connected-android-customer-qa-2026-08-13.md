# Connected Android Customer QA — 2026-08-13

## Result

Status: Passed

QA health score: 98/100. The implemented customer journey is ready for continued feature development. No reproducible critical, high, or medium defect was found, so no application-code fix was required.

## Environment

- Branch: `feat/customer-core-journey`
- Device: A059, Android 16 / API 36, 1080×2392 physical pixels
- Device ID: `00162358M004276`
- App: current debug APK built from this branch
- API: isolated local backend at `http://127.0.0.1:3300/api/v1/`, forwarded over USB with ADB
- Data: isolated PostgreSQL/Redis test containers and one disposable verified customer account
- Evidence: temporary screenshots and accessibility dumps under the operating-system temporary directory; none are committed

## Physical-device journey

| Area | Checks | Result |
| --- | --- | --- |
| Installation and launch | Built debug APK, installed with replacement, launched package | Passed |
| Authentication | Valid sign-in, invalid-password recovery, safe error copy, sign-out | Passed |
| Home | Premium hierarchy, phone fit, service loading, all four categories, scrolling | Passed |
| Location | Foreground permission state, privacy wording, allowed state | Passed |
| Service request | Plumbing selection, empty-description validation, realistic description, submit | Passed |
| Booking creation | Exactly one request created and returned to Home | Passed |
| Bookings | New request loaded with Matching state and verified-provider explanation | Passed |
| Help preview | Honest unavailable state and immediate-danger guidance | Passed as intentionally limited preview |
| Profile | Empty profile load, display-name save, saved confirmation, privacy notice | Passed |
| Navigation | Home, Bookings, Help, Profile selection and retained state | Passed |
| Accessibility surface | Semantic labels, 48px+ targets, status labels, field hints, error announcements | Passed for inspected controls |

## Backend and automated validation

- Liveness: passed
- Database readiness: passed
- Flutter analysis: passed
- Flutter tests: 43 passed
- Android debug APK build: passed
- Backend lint: passed
- Backend tests: 44 suites / 198 tests passed
- Backend build: passed
- `git diff --check`: passed

## Observations and deferred product scope

- The red DEBUG ribbon is expected in the debug APK and is absent from production builds.
- Help remains an honest preview until FN-075 implements customer support. This is not a regression.
- Provider acceptance, payment, and full live tracking are later tracked capabilities and were not represented as available.
- Registration delivery through real SMTP was not re-tested because local SMTP is intentionally unavailable; registration, OTP, retry, and failure behavior remain covered by backend/mobile tests.

## Ship-readiness summary

The connected Android app successfully completes the currently implemented customer path from sign-in through service request, booking visibility, profile management, and sign-out. The UI is visually consistent on the physical phone, primary controls respond, backend connectivity works over the approved local test path, and automated validation is green.
