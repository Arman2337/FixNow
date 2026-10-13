import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/data/last_good_cache.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_saved_data_banner.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/service_discovery_controller.dart';
import 'package:fixnow_mobile/features/services/service_discovery_screen.dart';
import 'package:fixnow_mobile/features/services/sub_service_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pump_idle.dart';

const _offline = ApiException(ApiFailureKind.offline, 'No network connection.');
const _serverDown = ApiException(ApiFailureKind.server, 'Server unavailable.');

const _plumbing = ServiceCategory(
  id: 'cat-1',
  name: 'Plumbing',
  slug: 'plumbing',
  description: 'Leaks and pipe repairs',
  iconName: 'plumbing',
  pricing: ServiceCategoryPricing(amountMinor: 49900, currency: 'INR'),
);

const _cleaning = ServiceCategory(
  id: 'cat-2',
  name: 'Cleaning',
  slug: 'cleaning',
  description: 'Deep cleaning',
);

class ScriptedCategories implements ServiceCategoryRepository {
  ScriptedCategories(this.answers);

  /// Consumed in order; the last entry for the repository sticks, so a screen
  /// that reloads on every build does not accidentally start succeeding.
  final List<Object> answers;
  int calls = 0;

  @override
  Future<List<ServiceCategory>> active() async {
    calls += 1;
    final answer = calls <= answers.length ? answers[calls - 1] : answers.last;
    if (answer is ApiException) throw answer;
    return answer as List<ServiceCategory>;
  }
}

LastGoodCache _cache({DateTime? now}) => LastGoodCache(
  store: MemorySnapshotStore(),
  scope: () => 'user-1',
  clock: () => now ?? DateTime.utc(2026, 10, 8, 12),
);

void main() {
  group('ServiceDiscoveryController offline-first', () {
    test('a successful load records the catalogue as last-good data', () async {
      final cache = _cache();
      final controller = ServiceDiscoveryController(
        ScriptedCategories([const [_plumbing, _cleaning]]),
        SubServiceRepository(_SilentApi()),
        cache: cache,
      );

      await controller.load();

      expect(controller.status, DiscoveryStatus.ready);
      expect(controller.isShowingSavedData, isFalse);
      expect(controller.savedDataAt, isNull);
      expect(await cache.read('service-categories'), isNotNull);
    });

    test('an offline launch with no saved data still reports offline', () async {
      final controller = ServiceDiscoveryController(
        ScriptedCategories([_offline]),
        SubServiceRepository(_SilentApi()),
        cache: _cache(),
      );

      await controller.load();

      expect(controller.status, DiscoveryStatus.offline);
      expect(controller.categories, isEmpty);
      expect(controller.isShowingSavedData, isFalse);
    });

    test('an offline launch with saved data renders it, marked as saved', () async {
      final savedAt = DateTime.utc(2026, 10, 8, 11, 40);
      final cache = _cache(now: savedAt);
      await ServiceDiscoveryController(
        ScriptedCategories([const [_plumbing, _cleaning]]),
        SubServiceRepository(_SilentApi()),
        cache: cache,
      ).load();

      final controller = ServiceDiscoveryController(
        ScriptedCategories([_offline]),
        SubServiceRepository(_SilentApi()),
        cache: cache,
      );
      await controller.load();

      expect(controller.status, DiscoveryStatus.ready);
      expect(controller.categories.map((c) => c.name), [
        'Plumbing',
        'Cleaning',
      ]);
      // The published price travels with the saved catalogue, so the card does
      // not silently lose it when the network is gone.
      expect(controller.categories.first.pricing?.amountMinor, 49900);
      expect(controller.isShowingSavedData, isTrue);
      expect(controller.savedDataAt, savedAt);
    });

    test('a server error is reported as an error, not disguised as saved data',
        () async {
      final cache = _cache();
      await ServiceDiscoveryController(
        ScriptedCategories([const [_plumbing]]),
        SubServiceRepository(_SilentApi()),
        cache: cache,
      ).load();

      final controller = ServiceDiscoveryController(
        ScriptedCategories([_serverDown]),
        SubServiceRepository(_SilentApi()),
        cache: cache,
      );
      await controller.load();

      expect(controller.status, DiscoveryStatus.error);
      expect(controller.isShowingSavedData, isFalse);
    });

    test('reconnecting replaces saved data with live data', () async {
      final cache = _cache();
      final controller = ServiceDiscoveryController(
        ScriptedCategories([
          const [_plumbing],
          _offline,
          const [_cleaning],
        ]),
        SubServiceRepository(_SilentApi()),
        cache: cache,
      );

      await controller.load();
      expect(controller.categories.single.name, 'Plumbing');

      await controller.load();
      expect(controller.isShowingSavedData, isTrue);
      expect(controller.categories.single.name, 'Plumbing');

      await controller.load();
      expect(controller.isShowingSavedData, isFalse);
      expect(controller.savedDataAt, isNull);
      expect(controller.categories.single.name, 'Cleaning');
    });

    test('a snapshot saved for another account is never shown', () async {
      final store = MemorySnapshotStore();
      await LastGoodCache(store: store, scope: () => 'user-1').write(
        'service-categories',
        [_plumbing.toJson()],
      );

      final controller = ServiceDiscoveryController(
        ScriptedCategories([_offline]),
        SubServiceRepository(_SilentApi()),
        cache: LastGoodCache(store: store, scope: () => 'user-2'),
      );

      await controller.load();

      expect(controller.status, DiscoveryStatus.offline);
      expect(controller.categories, isEmpty);
      expect(controller.isShowingSavedData, isFalse);
    });

    test('an unreadable snapshot falls back to the offline state', () async {
      final store = MemorySnapshotStore();
      await store.write(
        'service-categories.v1.user-1',
        '{"v":1,"savedAt":"2026-10-08T12:00:00.000Z","data":[{"id":7}]}',
      );
      final controller = ServiceDiscoveryController(
        ScriptedCategories([_offline]),
        SubServiceRepository(_SilentApi()),
        cache: LastGoodCache(store: store, scope: () => 'user-1'),
      );

      await controller.load();

      expect(controller.status, DiscoveryStatus.offline);
      expect(controller.isShowingSavedData, isFalse);
    });

    test('an empty live catalogue is cached as an honest empty state', () async {
      final cache = _cache();
      await ServiceDiscoveryController(
        ScriptedCategories([const <ServiceCategory>[]]),
        SubServiceRepository(_SilentApi()),
        cache: cache,
      ).load();

      final controller = ServiceDiscoveryController(
        ScriptedCategories([_offline]),
        SubServiceRepository(_SilentApi()),
        cache: cache,
      );
      await controller.load();

      expect(controller.status, DiscoveryStatus.empty);
      expect(controller.isShowingSavedData, isTrue);
    });
  });

  group('ServiceDiscoveryScreen saved-data banner', () {
    testWidgets('shows the stamp and keeps browsing the saved catalogue', (
      tester,
    ) async {
      final savedAt = DateTime.utc(2026, 10, 8, 11, 40);
      final store = MemorySnapshotStore();
      await LastGoodCache(
        store: store,
        scope: () => 'user-1',
        clock: () => savedAt,
      ).write('service-categories', [
        _plumbing.toJson(),
      ]);

      final controller = ServiceDiscoveryController(
        ScriptedCategories([_offline]),
        SubServiceRepository(_SilentApi()),
        cache: LastGoodCache(store: store, scope: () => 'user-1'),
      );
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ServiceDiscoveryScreen(
              controller: controller,
              locationController: LocationConsentController(
                _DeniedLocationGateway(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpIdle();

      expect(find.byType(FixSavedDataBanner), findsOneWidget);
      expect(find.text('Showing saved data'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Plumbing'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Plumbing'), findsOneWidget);
    });

    testWidgets('no banner on a normal live load', (tester) async {
      final controller = ServiceDiscoveryController(
        ScriptedCategories([const [_plumbing]]),
        SubServiceRepository(_SilentApi()),
        cache: _cache(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ServiceDiscoveryScreen(
              controller: controller,
              locationController: LocationConsentController(
                _DeniedLocationGateway(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpIdle();

      expect(find.byType(FixSavedDataBanner), findsNothing);
    });
  });
}

class _SilentApi implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      const ApiResponse(statusCode: 200, body: <Object?>[]);
}

class _DeniedLocationGateway implements LocationPermissionGateway {
  @override
  Future<LocationPermissionState> check() async =>
      LocationPermissionState.denied;

  @override
  Future<LocationPermissionState> request() async =>
      LocationPermissionState.denied;

  @override
  Future<bool> openSettings() async => true;
}