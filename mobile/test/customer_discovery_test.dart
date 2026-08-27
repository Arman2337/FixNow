import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/location/location_consent_card.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/service_discovery_controller.dart';
import 'package:fixnow_mobile/features/services/service_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_service_card.dart';
import 'pump_idle.dart';

class MockGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    return Position(
      longitude: 72.5714,
      latitude: 23.0225,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }
}

void main() {
  setUp(() {
    GeolocatorPlatform.instance = MockGeolocatorPlatform();
  });
  test('reports loading until category discovery completes', () async {
    final completer = Completer<List<ServiceCategory>>();
    final controller = ServiceDiscoveryController(
      PendingCategories(completer.future),
    );

    final load = controller.load();
    expect(controller.status, DiscoveryStatus.loading);
    completer.complete(const []);
    await load;
    expect(controller.status, DiscoveryStatus.empty);
  });

  testWidgets('permission denial preserves browsing and explains privacy', (
    tester,
  ) async {
    final location = LocationConsentController(
      FakeLocationGateway(LocationPermissionState.denied),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: LocationConsentCard(controller: location)),
      ),
    );
    await tester.pump();

    expect(
      find.text('You can still browse without sharing your location.'),
      findsOneWidget,
    );
    expect(find.textContaining('does not store it'), findsOneWidget);
    expect(find.widgetWithText(FixButton, 'Allow location'), findsOneWidget);
  });

  testWidgets('shows active categories with accessible labels', (tester) async {
    final discovery = ServiceDiscoveryController(
      FakeCategories([
        const ServiceCategory(
          id: '1',
          name: 'Plumbing',
          slug: 'plumbing',
          description: 'Leaks and pipe repairs',
          iconName: 'plumbing',
          pricing: ServiceCategoryPricing(
            amountMinor: 49900,
            currency: 'INR',
          ),
        ),
      ]),
    );
    final location = LocationConsentController(
      FakeLocationGateway(LocationPermissionState.granted),
    );
    await location.check();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ServiceDiscoveryScreen(
            controller: discovery,
            locationController: location,
          ),
        ),
      ),
    );
    await tester.pumpIdle();

    await tester.scrollUntilVisible(
      find.text('Plumbing'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.bySemanticsLabel('Plumbing service category'), findsOneWidget);
    expect(find.text('Leaks and pipe repairs'), findsOneWidget);
    // Scope the glyph check to the category card: quick-service chips may
    // legitimately reuse the same material glyph elsewhere on the screen.
    final categoryCard = find.ancestor(
      of: find.bySemanticsLabel('Plumbing service category'),
      matching: find.byType(FixServiceCard),
    );
    expect(categoryCard, findsOneWidget);
    expect(
      find.descendant(
        of: categoryCard,
        matching: find.byIcon(Icons.plumbing_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('₹499'), findsOneWidget);
  });

  testWidgets('categories without a published price show price on request', (
    tester,
  ) async {
    final discovery = ServiceDiscoveryController(
      FakeCategories([
        const ServiceCategory(
          id: '1',
          name: 'Cleaning',
          slug: 'cleaning',
        ),
      ]),
    );
    final location = LocationConsentController(
      FakeLocationGateway(LocationPermissionState.denied),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ServiceDiscoveryScreen(
            controller: discovery,
            locationController: location,
          ),
        ),
      ),
    );
    await tester.pumpIdle();

    await tester.scrollUntilVisible(
      find.text('Price on request'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Price on request'), findsOneWidget);
  });

  test('pricing parses bounded API payloads and renders rupee labels', () {
    final price = ServiceCategoryPricing.fromJson({
      'amountMinor': 49999,
      'currency': 'INR',
    });
    expect(price.displayLabel, '₹499.99');
    expect(
      const ServiceCategoryPricing(amountMinor: 49900, currency: 'INR')
          .displayLabel,
      '₹499',
    );

    expect(() => ServiceCategoryPricing.fromJson(<String, dynamic>{}),
        throwsFormatException);
    expect(
      () => ServiceCategoryPricing.fromJson({
        'amountMinor': '499',
        'currency': 'INR',
      }),
      throwsFormatException,
    );
  });

  testWidgets('shows offline recovery and retries', (tester) async {
    final repository = FakeCategories(
      const [],
      error: const ApiException(ApiFailureKind.offline, 'offline'),
    );
    final discovery = ServiceDiscoveryController(repository);
    final location = LocationConsentController(
      FakeLocationGateway(LocationPermissionState.denied),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ServiceDiscoveryScreen(
            controller: discovery,
            locationController: location,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('You are offline'), findsOneWidget);

    repository.error = null;
    await tester.tap(find.widgetWithText(FixButton, 'Try again'));
    await tester.pump();
    expect(find.text('No services available'), findsOneWidget);
    expect(repository.calls, 2);
  });
  testWidgets('quick services selects matching category or shows unavailable', (
    tester,
  ) async {
    final discovery = ServiceDiscoveryController(
      FakeCategories([
        const ServiceCategory(
          id: '1',
          name: 'Plumbing',
          slug: 'plumbing',
          description: 'Leaks and pipe repairs',
          iconName: 'plumbing',
        ),
      ]),
    );
    final location = LocationConsentController(
      FakeLocationGateway(LocationPermissionState.granted),
    );
    await location.check();

    ServiceCategory? selectedCategory;
    BookingLocationFix? selectedLocation;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ServiceDiscoveryScreen(
            controller: discovery,
            locationController: location,
            onCategorySelected: (category, location) {
              selectedCategory = category;
              selectedLocation = location;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Bring quick services fully into view
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pump();

    // Tap Plumber (available)
    await tester.tap(find.text('Plumber'));
    await tester.pump();
    expect(selectedCategory?.slug, 'plumbing');
    expect(selectedLocation, isNotNull);

    // Tap Electrician (unavailable)
    selectedCategory = null;
    await tester.tap(find.text('Electrician'));
    await tester.pumpIdle();
    expect(selectedCategory, isNull);
    expect(
      find.text('Electrician service is currently unavailable.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping location requests permission when not granted', (
    tester,
  ) async {
    final gateway = FakeLocationGateway(LocationPermissionState.denied);
    final location = LocationConsentController(gateway);
    final discovery = ServiceDiscoveryController(FakeCategories([]));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ServiceDiscoveryScreen(
            controller: discovery,
            locationController: location,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Enable Location'), findsOneWidget);

    await tester.tap(find.text('Enable Location'));
    await tester.pump();

    expect(gateway.requestCalled, isTrue);
  });
}

class FakeLocationGateway implements LocationPermissionGateway {
  FakeLocationGateway(this.state);
  LocationPermissionState state;
  bool requestCalled = false;
  @override
  Future<LocationPermissionState> check() async => state;
  @override
  Future<LocationPermissionState> request() async {
    requestCalled = true;
    return state;
  }

  @override
  Future<bool> openSettings() async => true;
}

class FakeCategories implements ServiceCategoryRepository {
  FakeCategories(this.items, {this.error});
  final List<ServiceCategory> items;
  ApiException? error;
  int calls = 0;
  @override
  Future<List<ServiceCategory>> active() async {
    calls += 1;
    if (error case final value?) throw value;
    return items;
  }
}

class PendingCategories implements ServiceCategoryRepository {
  PendingCategories(this.result);
  final Future<List<ServiceCategory>> result;
  @override
  Future<List<ServiceCategory>> active() => result;
}
