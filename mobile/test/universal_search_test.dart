import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/services/fix_universal_search_bar.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/service_discovery_controller.dart';
import 'package:fixnow_mobile/features/services/service_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
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

class _FakeLocationGateway implements LocationPermissionGateway {
  _FakeLocationGateway(this.state);
  LocationPermissionState state;

  @override
  Future<LocationPermissionState> check() async => state;

  @override
  Future<LocationPermissionState> request() async => state;

  @override
  Future<bool> openSettings() async => true;
}

class _FakeCategories implements ServiceCategoryRepository {
  _FakeCategories(this.items);
  final List<ServiceCategory> items;

  @override
  Future<List<ServiceCategory>> active() async => items;
}

void main() {
  setUp(() {
    GeolocatorPlatform.instance = MockGeolocatorPlatform();
  });

  final sampleCategories = [
    const ServiceCategory(
      id: 'plumbing',
      name: 'Plumbing',
      slug: 'plumbing',
      description: 'Pipes, taps, and drains',
    ),
    const ServiceCategory(
      id: 'electrical',
      name: 'Electrical',
      slug: 'electrical',
      description: 'Wiring, switches, and appliances',
    ),
  ];

  late ServiceDiscoveryController discoveryController;
  late LocationConsentController locationController;

  setUp(() {
    discoveryController = ServiceDiscoveryController(_FakeCategories(sampleCategories));
    locationController = LocationConsentController(_FakeLocationGateway(LocationPermissionState.granted));
  });

  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );
  }

  testWidgets('FixUniversalSearchBar renders input, clear button and filter chips', (tester) async {
    final searchController = TextEditingController();
    String query = '';
    SearchSortOption sort = SearchSortOption.relevance;
    SearchFilterOption filter = SearchFilterOption.all;

    await tester.pumpWidget(
      wrapWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return FixUniversalSearchBar(
              searchController: searchController,
              onSearchChanged: (val) => setState(() => query = val),
              onClear: () => setState(() {
                searchController.clear();
                query = '';
              }),
              activeSort: sort,
              onSortChanged: (s) => setState(() => sort = s),
              activeFilter: filter,
              onFilterChanged: (f) => setState(() => filter = f),
            );
          },
        ),
      ),
    );

    expect(find.byKey(const Key('universal_search_input')), findsOneWidget);
    expect(find.text('All Services'), findsOneWidget);
    expect(find.text('⚡ Emergency'), findsOneWidget);
    expect(find.text('Under ₹300'), findsOneWidget);

    // Enter query
    await tester.enterText(find.byKey(const Key('universal_search_input')), 'plumber');
    await tester.pump(const Duration(milliseconds: 50));

    expect(query, 'plumber');
    expect(find.byKey(const Key('universal_search_clear_button')), findsOneWidget);

    // Tap clear button
    await tester.tap(find.byKey(const Key('universal_search_clear_button')));
    await tester.pump(const Duration(milliseconds: 50));

    expect(searchController.text, '');
    expect(query, '');

    // Tap filter Under ₹300
    await tester.tap(find.text('Under ₹300'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(filter, SearchFilterOption.under300);
  });

  testWidgets('ServiceDiscoveryScreen live search filters sub-services and shows results', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrapWidget(
        ServiceDiscoveryScreen(
          controller: discoveryController,
          locationController: locationController,
        ),
      ),
    );
    await tester.pumpIdle();

    // Default discovery shows popular services
    expect(find.text('Popular services'), findsOneWidget);

    // Type "tap" into universal search
    await tester.enterText(find.byKey(const Key('universal_search_input')), 'tap');
    await tester.pump(const Duration(milliseconds: 50));

    // Search results section appears
    expect(find.textContaining('Search Results'), findsOneWidget);
    expect(find.text('Tap & Mixer Repair'), findsOneWidget);
    expect(find.text('₹149'), findsOneWidget);

    // Enter non-matching query
    await tester.enterText(find.byKey(const Key('universal_search_input')), 'xyznonexistent999');
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('No services found for'), findsOneWidget);
    expect(find.text('Tap Repair'), findsOneWidget); // In suggested chips

    // Clear search restores popular services
    await tester.tap(find.byKey(const Key('universal_search_clear_button')));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Popular services'), findsOneWidget);
  });
}
