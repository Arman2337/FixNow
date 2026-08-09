import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts each supported environment', () {
    for (final environment in AppEnvironment.values) {
      expect(AppEnvironment.fromName(environment.name), environment);
    }
  });

  test('rejects an unsupported environment', () {
    expect(
      () => AppEnvironment.fromName('local-production'),
      throwsArgumentError,
    );
  });
}
