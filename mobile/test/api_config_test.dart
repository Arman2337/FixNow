import 'package:fixnow_mobile/api/api_config.dart';
import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the local API default in development', () {
    expect(
      ApiConfig.baseUriFor(AppEnvironment.development),
      Uri.parse('http://127.0.0.1:3000/api/v1/'),
    );
  });

  test('requires HTTPS outside development', () {
    expect(
      () => ApiConfig.baseUriFor(AppEnvironment.production),
      throwsStateError,
    );
  });
}
