import 'package:fixnow_mobile/config/app_environment.dart';

/// FN-118: dev-only local payment bypass. Mirrors `LocalAuthConfig`. When
/// enabled it drives the deterministic fake gateway (ADR-0016) end to end so a
/// local build can complete a payment and reach the invoice — with no live
/// credentials and no card data. Never a production affordance: force-disabled
/// outside development regardless of the build flag.
class LocalPaymentConfig {
  LocalPaymentConfig._();

  static const _bypassConfigured = bool.fromEnvironment(
    'LOCAL_PAYMENT_BYPASS_ENABLED',
    defaultValue: false,
  );

  static bool get bypassEnabled => isPaymentBypassEnabled(
    environment: AppEnvironment.current,
    configured: _bypassConfigured,
  );

  static bool isPaymentBypassEnabled({
    required AppEnvironment environment,
    required bool configured,
  }) => configured && environment == AppEnvironment.development;
}
