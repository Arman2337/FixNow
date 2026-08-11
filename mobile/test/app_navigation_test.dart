import 'package:fixnow_mobile/app/app_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer navigation follows the approved destination order', () {
    expect(
      AppNavigation.forRole(AppShellRole.customer).map((item) => item.label),
      ['Home', 'Bookings', 'Help', 'Profile'],
    );
  });

  test('provider navigation follows the approved destination order', () {
    expect(
      AppNavigation.forRole(AppShellRole.provider).map((item) => item.label),
      ['Home', 'Active Job', 'Earnings', 'Profile'],
    );
  });
}
