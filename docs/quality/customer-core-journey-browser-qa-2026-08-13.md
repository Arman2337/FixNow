# Customer Core Journey Browser QA — 2026-08-13

## Outcome

FN-076 now provides a connected customer journey across authentication, email verification, service selection, location-backed request creation, and booking history. Flutter Web was added as an explicitly requested local QA target, and the compiled application was opened in Chrome at `http://127.0.0.1:8080`.

## Root causes corrected

- Service category rows had no tap handler or route.
- The app always rendered its shell and had no authentication screen.
- Registration did not expose the required email OTP verification step.
- The bookings tab was a static preview rather than API-backed history.
- Booking creation had no mobile repository, controller, form, idempotency header, or device-location capture.
- The backend had no HTTP CORS allowlist for Flutter Web.
- The repository had no Flutter Web host platform.
- Secure-storage initialization used a platform-only dependency on web; browser QA now uses an in-memory session while native platforms retain secure storage.
- The original API transport used `dart:io` `HttpClient`, which crashes in Chrome. It now uses the cross-platform HTTP client on native and web.

## UX decisions

- The customer does not choose a named provider because the approved backend contract creates an unassigned request that eligible providers accept. The UI states this clearly and uses “Find a verified provider.”
- Registration moves to an explicit six-digit email verification screen and supports resend, retry, and switching accounts.
- Booking status `REQUESTED` is presented as “Matching / Finding a provider,” with plain-language expectations.
- Forms retain a single primary action, tokenized spacing/type/color, accessible labels, loading prevention, inline failures, and narrow-screen scrolling.
- Web metadata uses the FixNow name and customer-facing description.

## Verification

- `flutter analyze`: passed with no issues.
- `flutter test`: 43 tests passed.
- `flutter build web`: passed; Wasm dry run also succeeded.
- Headless Chrome rendered the corrected phone-width authentication screen successfully; evidence: `fn-076-browser-proof.png`.
- `flutter build apk --debug`: passed before the phone was disconnected.
- Backend focused environment validation: 7 tests passed.
- Backend complete Jest suite: 44 suites / 197 tests passed.
- Isolated local API smoke: customer registration, verified login, booking creation (`REQUESTED`), and history lookup passed.
- Compiled Flutter Web application opened in visible Chrome at phone/desktop-responsive layout.

## Environment notes

- Local SMTP credentials are intentionally absent, so real email delivery cannot be completed locally. The UI accurately reports send failure and offers resend; verification APIs are covered by the backend suite.
- The optional gstack browser daemon was unavailable because its local installation lacked Playwright. Installed Chrome and Flutter's browser compilation/runtime were used instead.
- Headless Chrome command-line screenshots did not reliably wait for Flutter canvas paint on this Windows host, so blank captures were discarded rather than recorded as product evidence.
