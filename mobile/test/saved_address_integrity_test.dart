import 'package:fixnow_mobile/features/location/saved_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'an uninitialized address repository never silently substitutes a mock',
    () {
      expect(() => SavedAddressRepository.instance, throwsStateError);
    },
  );

  test('formatted address retains actual city, postal code and landmark', () {
    const address = SavedAddress(
      id: 'a',
      label: AddressLabel.home,
      customTitle: 'Home',
      flatBuilding: '12',
      streetArea: 'Market Road',
      landmark: 'Library',
      city: 'Surat',
      postalCode: '395001',
      latitude: 21.17,
      longitude: 72.83,
    );
    expect(
      address.formattedFull,
      '12, Market Road, (Near Library), Surat - 395001',
    );
  });
}
