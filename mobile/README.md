# FixNow mobile

Flutter application foundation for the FixNow customer and provider experiences. Authentication, navigation, booking, and production screens are intentionally deferred to their tracked tasks.

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
flutter run --dart-define=APP_ENV=development
```

Supported non-secret environment names are `development`, `staging`, and `production`. Environment-specific URLs and credentials must be supplied through an approved configuration mechanism in a later task; secrets must never be compiled into the application.

## Structure

- `lib/app/` owns application composition.
- `lib/config/` owns validated, non-secret environment selection.
- `test/` contains deterministic unit and widget tests.
- `android/` and `ios/` contain Flutter-managed platform projects.

All future UI must follow the repository root `DESIGN.md`.
