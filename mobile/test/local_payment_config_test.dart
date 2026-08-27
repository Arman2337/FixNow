import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:fixnow_mobile/features/payments/local_payment_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local payment bypass requires development and explicit configuration', () {
    expect(
      LocalPaymentConfig.isPaymentBypassEnabled(
        environment: AppEnvironment.development,
        configured: true,
      ),
      isTrue,
    );
    expect(
      LocalPaymentConfig.isPaymentBypassEnabled(
        environment: AppEnvironment.development,
        configured: false,
      ),
      isFalse,
    );
    expect(
      LocalPaymentConfig.isPaymentBypassEnabled(
        environment: AppEnvironment.staging,
        configured: true,
      ),
      isFalse,
    );
    expect(
      LocalPaymentConfig.isPaymentBypassEnabled(
        environment: AppEnvironment.production,
        configured: true,
      ),
      isFalse,
    );
  });
}
