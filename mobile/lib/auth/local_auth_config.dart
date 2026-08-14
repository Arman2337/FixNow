import 'package:fixnow_mobile/config/app_environment.dart';

class LocalAuthConfig {
  LocalAuthConfig._();

  static const _otpBypassConfigured = bool.fromEnvironment(
    'LOCAL_OTP_BYPASS_ENABLED',
    defaultValue: false,
  );

  static bool get otpBypassEnabled => isOtpBypassEnabled(
    environment: AppEnvironment.current,
    configured: _otpBypassConfigured,
  );

  static bool isOtpBypassEnabled({
    required AppEnvironment environment,
    required bool configured,
  }) => configured && environment == AppEnvironment.development;
}
