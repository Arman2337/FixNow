import 'package:fixnow_mobile/api/api_config.dart';
import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the Render API default in development', () {
    expect(
      ApiConfig.baseUriFor(AppEnvironment.development),
      Uri.parse('https://fixnow-lwys.onrender.com/api/v1/'),
    );
  });

  test('allows HTTPS in production', () {
    expect(
      ApiConfig.baseUriFor(AppEnvironment.production),
      Uri.parse('https://fixnow-lwys.onrender.com/api/v1/'),
    );
  });
}
