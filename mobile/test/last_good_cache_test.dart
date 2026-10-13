import 'dart:io';

import 'package:fixnow_mobile/data/last_good_cache.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileSnapshotStore', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('fixnow-cache-test');
    });

    tearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    FileSnapshotStore store() =>
        FileSnapshotStore(directory: () async => directory);

    test('survives a new store instance over the same directory', () async {
      await store().write('bookings.v1.user-1', '{"a":1}');

      // The point of the file store: the value outlives the object that wrote
      // it, which is what makes it work across app restarts.
      expect(await store().read('bookings.v1.user-1'), '{"a":1}');
    });

    test('keeps unrelated keys across writes', () async {
      await store().write('bookings.v1.user-1', '{"a":1}');
      await store().write('service-categories.v1.user-1', '{"b":2}');

      expect(await store().read('bookings.v1.user-1'), '{"a":1}');
      expect(await store().read('service-categories.v1.user-1'), '{"b":2}');
    });

    test('remove deletes only the named key', () async {
      await store().write('a.v1.user-1', '1');
      await store().write('b.v1.user-1', '2');

      await store().remove('a.v1.user-1');

      expect(await store().read('a.v1.user-1'), isNull);
      expect(await store().read('b.v1.user-1'), '2');
    });

    test('clear removes the backing file entirely', () async {
      await store().write('a.v1.user-1', '1');

      await store().clear();

      expect(await store().read('a.v1.user-1'), isNull);
      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('fixnow-last-good-cache.json'));
      expect(files, isEmpty);
    });

    test('a corrupt cache file reads as empty instead of throwing', () async {
      await File(
        '${directory.path}${Platform.pathSeparator}fixnow-last-good-cache.json',
      ).writeAsString('}{ not json');

      final cache = LastGoodCache(store: store(), scope: () => 'user-1');
      await cache.write('bookings', [
        {'id': 'b1'},
      ]);

      // The unreadable file is replaced by a valid one, so the app recovers
      // rather than being stuck refusing to cache anything.
      expect(await cache.read('bookings'), isNotNull);
    });
  });

  group('LastGoodCache', () {
    test('round-trips a payload with the time it was saved', () async {
      final now = DateTime.utc(2026, 10, 8, 12);
      final cache = LastGoodCache(
        store: MemorySnapshotStore(),
        scope: () => 'user-1',
        clock: () => now,
      );

      await cache.write('bookings', [
        {'id': 'b1'},
      ]);

      final snapshot = await cache.read('bookings');
      expect(snapshot, isNotNull);
      expect(snapshot!.savedAt, now);
      expect(snapshot.data, [
        {'id': 'b1'},
      ]);
    });

    test('returns null when nothing was ever saved', () async {
      final cache = LastGoodCache(
        store: MemorySnapshotStore(),
        scope: () => 'user-1',
      );
      expect(await cache.read('bookings'), isNull);
    });

    test('never leaks one account snapshot to another', () async {
      final store = MemorySnapshotStore();
      final first = LastGoodCache(store: store, scope: () => 'user-1');
      final second = LastGoodCache(store: store, scope: () => 'user-2');

      await first.write('bookings', [
        {'id': 'secret'},
      ]);

      expect(await first.read('bookings'), isNotNull);
      // A shared device signing into a different account must not render the
      // previous customer's bookings.
      expect(await second.read('bookings'), isNull);
    });

    test('reads and writes nothing while signed out', () async {
      final store = MemorySnapshotStore();
      final cache = LastGoodCache(store: store, scope: () => null);

      await cache.write('bookings', [
        {'id': 'b1'},
      ]);

      expect(await cache.read('bookings'), isNull);
      expect(await cache.read('bookings'), isNull);
    });

    test('survives a corrupt payload instead of throwing into the UI', () async {
      final store = MemorySnapshotStore();
      final cache = LastGoodCache(store: store, scope: () => 'user-1');
      await store.write('bookings.v1.user-1', 'not json at all');

      expect(await cache.read('bookings'), isNull);
    });

    test('discards a snapshot written by an incompatible envelope', () async {
      final store = MemorySnapshotStore();
      final cache = LastGoodCache(store: store, scope: () => 'user-1');
      await store.write(
        'bookings.v1.user-1',
        '{"v":99,"savedAt":"2026-10-08T12:00:00.000Z","data":[]}',
      );

      expect(await cache.read('bookings'), isNull);
    });

    test('discards a snapshot with an unreadable timestamp', () async {
      final store = MemorySnapshotStore();
      final cache = LastGoodCache(store: store, scope: () => 'user-1');
      await store.write(
        'bookings.v1.user-1',
        '{"v":1,"savedAt":"whenever","data":[]}',
      );

      expect(await cache.read('bookings'), isNull);
    });

    test('remove drops only the named snapshot', () async {
      final store = MemorySnapshotStore();
      final cache = LastGoodCache(store: store, scope: () => 'user-1');
      await cache.write('bookings', [
        {'id': 'b1'},
      ]);
      await cache.write('categories', [
        {'id': 'c1'},
      ]);

      await cache.remove('bookings');

      expect(await cache.read('bookings'), isNull);
      expect(await cache.read('categories'), isNotNull);
    });

    test('clear drops every snapshot on the device', () async {
      final store = MemorySnapshotStore();
      final cache = LastGoodCache(store: store, scope: () => 'user-1');
      await cache.write('bookings', [
        {'id': 'b1'},
      ]);
      await cache.write('categories', [
        {'id': 'c1'},
      ]);

      await cache.clear();

      expect(await cache.read('bookings'), isNull);
      expect(await cache.read('categories'), isNull);
    });

    test('a store that throws never breaks the screen that reads it', () async {
      final cache = LastGoodCache(
        store: ThrowingSnapshotStore(),
        scope: () => 'user-1',
      );
      await cache.write('bookings', [
        {'id': 'b1'},
      ]);

      expect(await cache.read('bookings'), isNull);
    });
  });

  group('offlineSnapshotAgeLabel', () {
    final now = DateTime.utc(2026, 10, 8, 12);

    test('describes the gap in human units', () {
      expect(offlineSnapshotAgeLabel(now, now: now), 'just now');
      expect(
        offlineSnapshotAgeLabel(now.subtract(const Duration(seconds: 40)), now: now),
        'just now',
      );
      expect(
        offlineSnapshotAgeLabel(now.subtract(const Duration(minutes: 12)), now: now),
        '12m ago',
      );
      expect(
        offlineSnapshotAgeLabel(now.subtract(const Duration(minutes: 59)), now: now),
        '59m ago',
      );
      expect(
        offlineSnapshotAgeLabel(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
      expect(
        offlineSnapshotAgeLabel(now.subtract(const Duration(hours: 23)), now: now),
        '23h ago',
      );
      expect(
        offlineSnapshotAgeLabel(now.subtract(const Duration(days: 4)), now: now),
        '4d ago',
      );
    });

    test('never counts backwards when a device clock moves', () {
      expect(
        offlineSnapshotAgeLabel(
          now.add(const Duration(minutes: 5)),
          now: now,
        ),
        'just now',
      );
    });
  });

  group('cached model round-trips', () {
    test('CustomerBooking survives a save and restore', () {
      final original = CustomerBooking(
        id: 'b-1',
        serviceCategoryId: 'cat-1',
        status: 'EN_ROUTE',
        description: 'Leaking tap',
        createdAt: DateTime.utc(2026, 10, 1, 9, 30),
        version: 4,
        providerName: 'Suresh',
        providerPhone: '+919000000000',
        providerRating: 4.8,
        providerJobsCount: 128,
        locationLatitude: 23.0225,
        locationLongitude: 72.5714,
        scheduledAt: DateTime.utc(2026, 10, 2, 8),
        items: const [
          BookingLineItem(
            id: 'sub-1',
            name: 'Tap repair',
            quantity: 2,
            unitPriceMinor: 49900,
            durationMinutes: 45,
          ),
        ],
        pricing: const BookingPricing(
          subtotalMinor: 99800,
          gstMinor: 17964,
          totalMinor: 117764,
          currency: 'INR',
        ),
        estimatedDurationMinutes: 90,
        lineItems: const [
          LineItem(type: 'LABOUR', description: 'Labour', amount: 99800),
        ],
      );

      final restored = CustomerBooking.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.serviceCategoryId, original.serviceCategoryId);
      expect(restored.status, original.status);
      expect(restored.description, original.description);
      expect(restored.createdAt, original.createdAt);
      expect(restored.version, original.version);
      expect(restored.providerName, original.providerName);
      expect(restored.providerPhone, original.providerPhone);
      expect(restored.providerRating, original.providerRating);
      expect(restored.providerJobsCount, original.providerJobsCount);
      expect(restored.locationLatitude, original.locationLatitude);
      expect(restored.locationLongitude, original.locationLongitude);
      expect(restored.scheduledAt, original.scheduledAt);
      expect(restored.estimatedDurationMinutes, 90);
      expect(restored.items?.single.name, 'Tap repair');
      expect(restored.items?.single.quantity, 2);
      expect(restored.items?.single.unitPriceMinor, 49900);
      expect(restored.items?.single.durationMinutes, 45);
      expect(restored.pricing?.totalMinor, 117764);
      expect(restored.lineItems.single.description, 'Labour');
    });

    test('ServiceCategory survives a save and restore', () {
      final original = const ServiceCategory(
        id: 'cat-1',
        name: 'Plumbing',
        slug: 'plumbing',
        description: 'Leaks and pipe repairs',
        iconName: 'plumbing',
        pricing: ServiceCategoryPricing(amountMinor: 49900, currency: 'INR'),
        isEmergency: true,
        verifiedProCount: 12,
        onlineProCount: 4,
        rating: 4.6,
        reviewCount: 87,
      );

      final restored = ServiceCategory.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.slug, original.slug);
      expect(restored.description, original.description);
      expect(restored.iconName, original.iconName);
      expect(restored.pricing?.amountMinor, 49900);
      expect(restored.pricing?.currency, 'INR');
      expect(restored.isEmergency, isTrue);
      expect(restored.verifiedProCount, 12);
      expect(restored.onlineProCount, 4);
      expect(restored.rating, 4.6);
      expect(restored.reviewCount, 87);
    });

    test('a category with no published pricing keeps it absent', () {
      const original = ServiceCategory(
        id: 'cat-2',
        name: 'Handyman',
        slug: 'handyman',
      );

      final restored = ServiceCategory.fromJson(original.toJson());

      expect(restored.pricing, isNull);
      expect(restored.isEmergency, isFalse);
      expect(restored.rating, isNull);
    });
  });
}

class ThrowingSnapshotStore implements SnapshotStore {
  @override
  Future<String?> read(String key) async =>
      throw StateError('storage unavailable');

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('storage unavailable');

  @override
  Future<void> remove(String key) async =>
      throw StateError('storage unavailable');

  @override
  Future<void> clear() async => throw StateError('storage unavailable');
}