import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_address_selector.dart';
import 'package:fixnow_mobile/features/location/saved_address.dart';
import 'package:fixnow_mobile/features/profile/customer_profile.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_controller.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_repository.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );

void main() {
  setUp(() {
    SavedAddressRepository.instance.reset();
  });

  group('SavedAddressRepository', () {
    test('manages addresses, defaults, and removals accurately', () {
      final repo = SavedAddressRepository.instance;
      expect(repo.addresses.length, 2);
      expect(repo.defaultAddress?.customTitle, 'Home');

      // Add a new address
      const newAddr = SavedAddress(
        id: 'addr-custom-1',
        label: AddressLabel.other,
        customTitle: 'Gym',
        flatBuilding: 'FitPro Arena',
        streetArea: '100ft Road, Indiranagar',
        latitude: 12.9784,
        longitude: 77.6408,
      );
      repo.saveAddress(newAddr);
      expect(repo.addresses.length, 3);

      // Set Gym as default
      repo.setDefault('addr-custom-1');
      expect(repo.defaultAddress?.id, 'addr-custom-1');

      // Delete Gym
      repo.deleteAddress('addr-custom-1');
      expect(repo.addresses.length, 2);
      expect(repo.defaultAddress?.id, 'addr-home-1');
    });
  });

  group('SavedAddressSelectorCard', () {
    testWidgets('switches selected address when tapping chips', (tester) async {
      SavedAddress? selected;

      await tester.pumpWidget(
        host(
          SavedAddressSelectorCard(
            onAddressSelected: (addr) => selected = addr,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Service Address'), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Office'), findsWidgets);
      expect(find.textContaining('Flat 402, Lotus Heights'), findsOneWidget);

      // Tap Office chip
      await tester.tap(find.text('Office').first);
      await tester.pumpAndSettle();

      expect(selected?.customTitle, 'Office');
      expect(find.textContaining('Desk 5B, WeWork Galaxy'), findsOneWidget);
    });
  });

  group('AddEditAddressModalSheet', () {
    testWidgets('validates fields and saves new address', (tester) async {
      SavedAddress? created;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  created = await AddEditAddressModalSheet.show(context);
                },
                child: const Text('Add Address'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Address'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Address'), findsOneWidget);

      // Fill in form
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Villa 14, Palm Grove');
      await tester.enterText(textFields.at(1), 'Green Glen Layout, Bellandur');
      await tester.enterText(textFields.at(2), 'Opposite EcoSpace');

      // Tap Save Address
      await tester.tap(find.text('Save Address'));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created!.flatBuilding, 'Villa 14, Palm Grove');
      expect(SavedAddressRepository.instance.addresses.length, 3);
    });
  });

  group('CustomerProfileScreen Saved Addresses integration', () {
    testWidgets('displays saved addresses and allows deleting an address',
        (tester) async {
      final repository = FakeProfileRepository(
        const CustomerProfile(displayName: 'Rahul'),
      );
      final controller = CustomerProfileController(repository);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: CustomerProfileScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved addresses'), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Office'), findsWidgets);

      // Tap Delete on Office
      final deleteButtons = find.text('Delete');
      expect(deleteButtons, findsWidgets);
      await tester.ensureVisible(deleteButtons.first);
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Office should now be deleted from repository
      expect(SavedAddressRepository.instance.addresses.length, 1);
    });
  });
}

class FakeProfileRepository implements CustomerProfileRepository {
  FakeProfileRepository(this.profile, {this.error});
  CustomerProfile profile;
  final ApiException? error;
  String? updatedWith;

  @override
  Future<CustomerProfile> read() async {
    if (error case final value?) throw value;
    return profile;
  }

  @override
  Future<CustomerProfile> update(String displayName) async {
    updatedWith = displayName;
    profile = CustomerProfile(displayName: displayName);
    return profile;
  }
}
