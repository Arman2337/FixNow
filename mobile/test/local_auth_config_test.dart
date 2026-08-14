import 'package:fixnow_mobile/auth/local_auth_config.dart';
import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local OTP bypass requires development and explicit configuration', () {
    expect(
      LocalAuthConfig.isOtpBypassEnabled(
        environment: AppEnvironment.development,
        configured: true,
      ),
      isTrue,
    );
    expect(
      LocalAuthConfig.isOtpBypassEnabled(
        environment: AppEnvironment.development,
        configured: false,
      ),
      isFalse,
    );
    expect(
      LocalAuthConfig.isOtpBypassEnabled(
        environment: AppEnvironment.staging,
        configured: true,
      ),
      isFalse,
    );
    expect(
      LocalAuthConfig.isOtpBypassEnabled(
        environment: AppEnvironment.production,
        configured: true,
      ),
      isFalse,
    );
  });
}
