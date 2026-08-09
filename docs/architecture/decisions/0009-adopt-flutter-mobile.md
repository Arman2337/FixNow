# ADR-0009: Adopt Flutter for the mobile application

- Status: Accepted
- Date: 2026-08-09
- Owners: FixNow engineering

## Context

FixNow needs one mobile application serving customer and provider roles while preserving platform-quality Android and iOS behavior. The foundation requires a typed, testable client with consistent tooling and a clear boundary from backend domain logic. The user explicitly approved initializing Flutter through FN-034.

## Decision

Use stable-channel Flutter and Dart for the application under `mobile/`.

- Maintain one application with role-aware composition added by later tasks.
- Keep environment selection compile-time and non-secret through `--dart-define=APP_ENV=development|staging|production`.
- Keep business authority in backend APIs and use versioned shared contracts rather than importing backend source.
- Support Android and iOS initially; additional platforms require a separate task and validation.
- Follow `DESIGN.md` for all user-interface implementation.

## Consequences

Flutter provides a shared typed codebase, consistent testing, and common design primitives across the two mobile platforms. The team must maintain Flutter/Dart expertise and still test platform-specific behavior, accessibility, permissions, lifecycle, packaging, and releases. Native integrations remain isolated behind explicit adapters.

## Alternatives considered

- Separate native Android and iOS applications provide maximum platform control but duplicate product implementation and increase foundation cost.
- React Native shares code but would add a JavaScript mobile toolchain without a demonstrated advantage for this repository.
- A mobile web application cannot satisfy expected device integration and platform experience requirements by itself.

## Validation

Validate the generated foundation with `flutter pub get`, `flutter analyze`, and `flutter test` on the pinned supported Flutter toolchain. Reconsider if measured platform requirements cannot be met safely or maintainably through Flutter.
