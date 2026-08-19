import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/location/location_consent_card.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/service_discovery_controller.dart';
import 'package:fixnow_mobile/features/services/service_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';

class MockGeolocatorPlatform extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
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
        ),
      ]),
    );
    final location = LocationConsentController(
      FakeLocationGateway(LocationPermissionState.granted),
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

    await tester.scrollUntilVisible(
      find.text('Plumbing'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.bySemanticsLabel('Plumbing service category'), findsOneWidget);
    expect(find.text('Leaks and pipe repairs'), findsOneWidget);
    expect(find.byIcon(Icons.plumbing_outlined), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(3));
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
  testWidgets('quick services selects matching category or shows unavailable', (tester) async {
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
    
    ServiceCategory? selectedCategory;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ServiceDiscoveryScreen(
            controller: discovery,
            locationController: location,
            onCategorySelected: (c) => selectedCategory = c,
          ),
        ),
      ),
    );
    await tester.pump();

    // Tap Plumber (available)
    await tester.tap(find.text('Plumber'));
    await tester.pump();
    expect(selectedCategory?.slug, 'plumbing');

    // Tap Electrician (unavailable)
    selectedCategory = null;
    await tester.tap(find.text('Electrician'));
    await tester.pumpAndSettle();
    expect(selectedCategory, isNull);
    expect(find.text('Electrician service is currently unavailable.'), findsOneWidget);
  });

  testWidgets('tapping location requests permission when not granted', (tester) async {
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
