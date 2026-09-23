import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _RecordingRealtimeClient extends Fake implements RealtimeClient {
  _RecordingRealtimeClient({this.failConsent = false});

  final bool failConsent;
  final StreamController<RealtimeProjection> incoming =
      StreamController<RealtimeProjection>();
  final List<Map<String, Object?>> frames = [];
  void Function(bool granted)? onConsent;
  int presenceCalls = 0;
  int consentGrants = 0;
  int consentRevocations = 0;

  @override
  Stream<RealtimeProjection> get projections => incoming.stream;

  @override
  Future<void> dispose() async {
    await incoming.close();
  }

  @override
  Future<void> subscribeBooking(String bookingId) async {}

  @override
  Future<void> sendPresence(bool online) async {
    presenceCalls += 1;
  }

  @override
  @override
  Future<void> sendLocationConsent({
    required String bookingId,
    required bool granted,
    required String noticeVersion,
  }) async {
    if (failConsent) {
      throw StateError('stale-or-rate-limited');
    }
    granted ? consentGrants++ : consentRevocations++;
    onConsent?.call(granted);
  }

  @override
  Future<void> sendLocation({
    required String bookingId,
    required int sequence,
    required DateTime capturedAt,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) async {
    frames.add({
      'bookingId': bookingId,
      'sequence': sequence,
      'capturedAt': capturedAt,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
    });
  }
}

class _ProviderTransport implements ApiTransport {
  _ProviderTransport({this.jobs = const [], this.paymentPaid = false});
  final List<CustomerBooking> jobs;
  final bool paymentPaid;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path == 'providers/me/jobs' ||
        request.path.startsWith('bookings?')) {
      return const ApiResponse(
        statusCode: 200,
        body: {'bookings': <Object?>[], 'nextCursor': null},
      );
    }
    if (request.path.startsWith('providers/me/bookings/') &&
        request.path.endsWith('/payment-status')) {
      return ApiResponse(statusCode: 200, body: {'paid': paymentPaid});
    }
    throw const ApiException(
      ApiFailureKind.invalidResponse,
      'Unexpected request',
    );
  }
}

class _FixedGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  _FixedGeolocatorPlatform({
    this.permission,
    this.position,
    this.error,
    this.onCurrentPosition,
  });
  LocationPermission? permission;
  Position? position;
  Object? error;
  void Function()? onCurrentPosition;

  /// Queued fixes returned one per getCurrentPosition call before falling
  /// back to [position]; lets tests script coarse-then-accurate readings.
  List<Position> currentPositions = [];

  /// Overrides the last-known fix returned to the controller.
  Position? lastKnownPosition;
  int currentCalls = 0;
  int requestPermissionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      permission ?? LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return permission ?? LocationPermission.whileInUse;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    currentCalls += 1;
    onCurrentPosition?.call();
    if (currentPositions.isNotEmpty) return currentPositions.removeAt(0);
    if (error != null) throw error!;
    return position!;
  }

  @override
  Future<Position?> getLastKnownPosition({bool? forceLocationManager}) async {
    if (lastKnownPosition != null) return lastKnownPosition;
    if (error != null) throw error!;
    return position;
  }
}

CustomerBooking _job(
  String id, {
  String status = 'EN_ROUTE',
  double? lat,
  double? lng,
}) => CustomerBooking(
  id: id,
  serviceCategoryId: 'category-1',
  status: status,
  description: 'Kitchen sink leak',
  createdAt: DateTime.utc(2026, 8, 14),
  version: 1,
  locationLatitude: lat,
  locationLongitude: lng,
);

ProviderController _controller({
  required _ProviderTransport transport,
  required _RecordingRealtimeClient realtime,
}) => ProviderController(
  ProviderRepository(api: transport, accessToken: () async => 'token'),
  realtime: realtime,
);

Position _gpsPosition() => _gpsAt(9.0);

Position _gpsAt(double accuracy, {DateTime? timestamp}) => Position(
  latitude: 23.0225,
  longitude: 72.5714,
  timestamp: timestamp ?? DateTime.utc(2026, 9, 18, 9),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late _FixedGeolocatorPlatform gps;

  setUp(() {
    gps = _FixedGeolocatorPlatform(position: _gpsPosition());
    GeolocatorPlatform.instance = gps;
  });

  test('tracks a flat booking.tracking.v1 projection with route + location',
      () async {
    final realtime = _RecordingRealtimeClient();
    final controller = _controller(
      transport: _ProviderTransport(),
      realtime: realtime,
    );
    addTearDown(controller.dispose);
    controller.jobs = [_job('booking-1')];

    realtime.incoming.add(
      const RealtimeProjection({
        'type': 'booking.projection-updated.v1',
        'data': {
          'bookingId': 'booking-1',
          'status': 'EN_ROUTE',
          'sequence': 4,
          'locationAvailability': 'live',
          'location': {
            'latitude': 23.01,
            'longitude': 72.56,
            'accuracyMeters': 12.0,
            'capturedAt': '2026-09-18T09:00:00.000Z',
            'receivedAt': '2026-09-18T09:00:01.000Z',
          },
          'route': {
            'distanceMeters': 4200.0,
            'durationSeconds': 600,
            'coordinates': [
              [72.56, 23.01],
              [72.57, 23.02],
            ],
          },
        },
      }),
    );
    await realtime.incoming.close();
    await Future<void>.delayed(Duration.zero);

    expect(controller.currentLocation?.latitude, 23.01);
    expect(controller.currentLocation?.accuracyMeters, 12.0);
    expect(controller.currentRoute?.distanceMeters, 4200.0);
    expect(controller.currentRoute?.coordinates.length, 2);
  });

  test('projection for another booking does not touch cockpit map data',
      () async {
    final realtime = _RecordingRealtimeClient();
    final controller = _controller(
      transport: _ProviderTransport(),
      realtime: realtime,
    );
    addTearDown(controller.dispose);
    controller.jobs = [_job('booking-1')];

    realtime.incoming.add(
      const RealtimeProjection({
        'type': 'booking.projection-updated.v1',
        'data': {
          'bookingId': 'booking-2',
          'status': 'EN_ROUTE',
          'sequence': 4,
          'locationAvailability': 'live',
          'location': {
            'latitude': 1.0,
            'longitude': 2.0,
            'accuracyMeters': 10.0,
            'capturedAt': '2026-09-18T09:00:00.000Z',
            'receivedAt': '2026-09-18T09:00:01.000Z',
          },
        },
      }),
    );
    await realtime.incoming.close();
    await Future<void>.delayed(Duration.zero);

    expect(controller.currentLocation, isNull);
    expect(controller.currentRoute, isNull);
  });

  test('publishes the real GPS fix captured by the device', () async {
    final realtime = _RecordingRealtimeClient();
    final transport = _ProviderTransport();
    final controller = _controller(transport: transport, realtime: realtime);
    addTearDown(controller.dispose);
    controller.jobs = [_job('booking-1', lat: 1.0, lng: 2.0)];

    await controller.publishCurrentLocation(controller.jobs.first);

    expect(realtime.frames, hasLength(1));
    final frame = realtime.frames.single;
    expect(frame['latitude'], 23.0225);
    expect(frame['longitude'], 72.5714);
    expect(frame['accuracyMeters'], 9.0);
    expect(frame['capturedAt'], DateTime.utc(2026, 9, 18, 9));
  });

  test('does not publish when consent was revoked during the GPS await',
      () async {
    final realtime = _RecordingRealtimeClient();
    final controller = _controller(
      transport: _ProviderTransport(),
      realtime: realtime,
    );
    addTearDown(controller.dispose);
    controller.jobs = [_job('booking-1', lat: 1.0, lng: 2.0)];
    controller.locationSharing['booking-1'] = true;
    gps.onCurrentPosition = () {
      controller.locationSharing['booking-1'] = false;
    };

    await controller.publishCurrentLocation(controller.jobs.first);

    expect(realtime.frames, isEmpty);
  });

  test('skips a publish that would hit the server rate limit', () async {
    final realtime = _RecordingRealtimeClient();
    final controller = _controller(
      transport: _ProviderTransport(),
      realtime: realtime,
    );
    addTearDown(controller.dispose);
    controller.jobs = [_job('booking-1', lat: 1.0, lng: 2.0)];

    await controller.publishCurrentLocation(controller.jobs.first);
    await controller.publishCurrentLocation(controller.jobs.first);

    expect(realtime.frames, hasLength(1));
  });

  test('retries for a usable fix when the first reading is too coarse',
      () async {
    final realtime = _RecordingRealtimeClient();
    final controller = _controller(
      transport: _ProviderTransport(),
      realtime: realtime,
    );
    addTearDown(controller.dispose);
    controller.jobs = [_job('booking-1', lat: 1.0, lng: 2.0)];
    gps.currentPositions = [_gpsAt(250), _gpsAt(8)];

    await controller.publishCurrentLocation(controller.jobs.first);

    expect(realtime.frames, hasLength(1));
    expect(realtime.frames.single['accuracyMeters'], 8.0);
  });

  test('prefers a fresh last-known fix over a persistently coarse reading',
      () async {
    final realtime = _RecordingRealtimeClient();
    final controller = _controller(
      transport: _ProviderTransport(),
      realtime: realtime,
    );
    addTearDown(controller.dispose);
    controller.jobs = [_job('booking-1', lat: 1.0, lng: 2.0)];
    gps.currentPositions = [_gpsAt(250), _gpsAt(240)];
    gps.lastKnownPosition = _gpsAt(
      12,
      timestamp: DateTime.now().subtract(const Duration(seconds: 20)),
    );

    await controller.publishCurrentLocation(controller.jobs.first);

    expect(realtime.frames.single['accuracyMeters'], 12.0);
  });
}
