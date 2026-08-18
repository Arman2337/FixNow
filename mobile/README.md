# FixNow mobile

Flutter application foundation for the FixNow customer and provider experiences. The application shell, role-aware primary navigation, design tokens, reusable UI primitives, authentication state, and initial customer discovery/profile screens are established; registration UI, booking, and later production screens remain deferred to their tracked tasks.

## Prerequisites

- Flutter 3.38.9 stable or a compatible newer stable release
- Dart 3.10.8 or the version bundled with the supported Flutter SDK
- Android Studio/SDK for Android development
- Xcode and CocoaPods on macOS for iOS development

## Setup and validation

From `mobile/`:

```bash
flutter pub get
flutter analyze
flutter test
```

Run the development environment on an available device:

```bash
flutter run --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1/
```

When the backend's explicit local OTP bypass is enabled, add
`--dart-define=LOCAL_OTP_BYPASS_ENABLED=true` to show the local verification
hint. This hint is suppressed outside `APP_ENV=development`; the backend remains
the authoritative enforcement boundary.

### Local Google Maps development key

Live provider tracking uses Google Maps only after the backend has authorized a
fresh provider location for the assigned customer. Enable **Maps SDK for
Android** in a development-only Google Cloud project, restrict its key to the
`com.fixnow.fixnow_mobile` Android application, and add this untracked value to
`mobile/android/local.properties`:

```properties
GOOGLE_MAPS_API_KEY=your-development-key
```

Never commit the key. A missing key leaves the app buildable but Google Maps
cannot display tiles; it does not bypass authorization or freshness rules.

Supported non-secret environment names are `development`, `staging`, and `production`. `API_BASE_URL` must be an absolute HTTPS URL for staging and production; development defaults to `http://127.0.0.1:3000/api/v1/`. Credentials and tokens must never be supplied through compile-time configuration.

## Structure

- `lib/app/` owns application composition.
- `lib/config/` owns validated, non-secret environment selection.
- `lib/api/` owns bounded HTTP transport, timeouts, safe errors, and idempotent retry policy.
- `lib/auth/` owns authentication state, token renewal, logout, and secure session storage.
- `lib/features/` owns bounded customer and provider product experiences.
- `lib/design_system/` owns the `DESIGN.md` token mappings, theme, and reusable primitives.
- `test/` contains deterministic unit and widget tests.
- `android/` and `ios/` contain Flutter-managed platform projects.

All future UI must follow the repository root `DESIGN.md`.

## Application shell state

FN-035 intentionally uses Flutter's built-in `ChangeNotifier` through
`AppShellController` for the small, synchronous navigation boundary. The shell
owns only the selected primary destination and preserves destination widgets in
an `IndexedStack`. Product, session, server, and workflow state do not belong in
this controller; later tasks must select state tooling based on their actual
requirements instead of expanding shell state into a global store.

Customer navigation follows Home, Bookings, Help, and Profile. Provider
navigation follows Home, Active Job, Earnings, and Profile. Authentication will
select the role-specific shell in a later UI task; the current shell defaults to
the customer role without implementing registration or product workflows.

## Authentication boundary

FN-036 stores session credentials only through platform secure storage (Android
Keystore and Apple Keychain). Android backups are disabled, Android API 23 is
the minimum supported version, and iOS runner configurations include Keychain
Sharing entitlements. Refresh and logout requests are never automatically
retried because refresh tokens rotate and are replay protected; only safe GET
requests receive a bounded retry.

## Customer discovery and location

FN-037 connects the customer Home destination to active service categories and
foreground location consent, and connects Profile to the approved display-name
contract. Location remains optional: denial never blocks browsing, and this
feature neither stores coordinates nor creates bookings. Android and iOS request
only foreground/when-in-use location permission with reviewed purpose text.
