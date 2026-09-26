import 'package:fixnow_mobile/app/app_route_restoration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trips and clears the active route for the same user', () async {
    final values = <String, String>{};
    final store = AppRouteRestorationStore(
      read: (key) async => values[key],
      write: (key, value) async => values[key] = value,
      delete: (key) async => values.remove(key),
    );

    expect(await store.readRoute(), isNull);

    await store.saveTracking(userId: 'user-1', bookingId: 'booking-1');
    expect(
      await store.readRoute(),
      const RestorableAppRoute(
        userId: 'user-1',
        name: 'tracking',
        argument: 'booking-1',
      ),
    );

    await store.clear();
    expect(await store.readRoute(), isNull);
  });

  test('ignores malformed persisted route data', () async {
    final store = AppRouteRestorationStore(
      read: (_) async => 'not-a-route',
      write: (_, _) async {},
      delete: (_) async {},
    );

    expect(await store.readRoute(), isNull);
  });
}
