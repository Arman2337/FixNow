import 'dart:async';
import 'dart:io';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_repository.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Who owns the socket.
///
/// The app builds one socket for bookings, provider and notifications and one
/// more per booking-tracking screen. The gateway allows three connections per
/// principal, so those two clients are the whole budget: a second feature socket
/// would be refused with `limit-exceeded`, and the symptom is not an error - it
/// is a tracking screen whose live location never moves.
///
/// Sharing one socket is only safe if exactly one thing disposes it. Before this
/// was pinned, BookingController and ProviderController each disposed a client
/// they had been handed while NotificationController did not. That was invisible
/// while every feature had its own socket, and it would have killed the other two
/// consumers the moment they shared one - a failure that would have looked like
/// "notifications randomly stop".
class _OwnershipRealtimeClient extends Fake implements RealtimeClient {
  int disposeCalls = 0;
  final incoming = StreamController<RealtimeProjection>.broadcast();

  @override
  Stream<RealtimeProjection> get projections => incoming.stream;

  @override
  Stream<RealtimeProjection> get notifications => incoming.stream;

  @override
  void dispose() {
    // Not calling super.dispose(): RealtimeClient extends ChangeNotifier, and a
    // fake that inherits its whole lifecycle would be testing the base class
    // rather than this ownership contract.
    disposeCalls += 1;
  }
}

void main() {
  // Disposing a ChangeNotifier twice throws in debug, which is what makes
  // "somebody else already disposed it" a loud failure rather than a silent one.
  // These tests assert the ownership directly instead, so the reason for the
  // failure is legible.

  test('BookingController borrows the socket and does not dispose it', () {
    final realtime = _OwnershipRealtimeClient();
    final controller = BookingController(
      _unusedRepository(),
      realtime: realtime,
    );

    controller.dispose();

    expect(
      realtime.disposeCalls,
      0,
      reason:
          'the app shares this socket with the provider and notification '
          'controllers; disposing it here would kill them too',
    );
  });

  test('ProviderController borrows the socket and does not dispose it', () {
    final realtime = _OwnershipRealtimeClient();
    final controller = ProviderController(
      _unusedProviderRepository(),
      realtime: realtime,
      currentUserId: () => 'user-1',
    );

    controller.dispose();

    expect(
      realtime.disposeCalls,
      0,
      reason: 'same shared socket as BookingController',
    );
  });

  test('NotificationController already borrowed rather than owned', () async {
    final realtime = _OwnershipRealtimeClient();
    final controller = NotificationController(
      _unusedNotificationRepository(),
      realtime: realtime,
    );
    // The constructor kicks off a load; let it settle so disposal is not racing
    // a notifyListeners and reported as "used after being disposed".
    await Future<void>.delayed(Duration.zero);

    controller.dispose();

    expect(realtime.disposeCalls, 0);
  });

  test('the app creates two sockets, not one per feature', () {
    // The actual budget. Three is the gateway's per-principal limit, so one
    // shared socket plus one per tracking screen is the whole allowance, and
    // this is the assertion that would have caught the original four.
    final source = File('lib/app/app.dart').readAsStringSync();
    final creations = RegExp(r'_createRealtimeClient\(\)').allMatches(source);
    // Three textual occurrences: the declaration itself, the shared client, and
    // the per-screen one. A fourth construction site is a fourth socket.
    expect(
      creations.length,
      lessThanOrEqualTo(3),
      reason:
          'only the shared client and the booking-tracking client may be '
          'created; every extra one can be refused with limit-exceeded',
    );
    expect(
      RegExp(
        r'_sharedRealtime\s*=\s*_createRealtimeClient\(\)',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('the three long-lived consumers can share one socket without fighting '
      'over it', () async {
    // The scenario the sharing exists for: three controllers, one socket, torn
    // down in the order the app tears them down.
    final realtime = _OwnershipRealtimeClient();
    final bookings = BookingController(_unusedRepository(), realtime: realtime);
    final provider = ProviderController(
      _unusedProviderRepository(),
      realtime: realtime,
      currentUserId: () => 'user-1',
    );
    final notifications = NotificationController(
      _unusedNotificationRepository(),
      realtime: realtime,
    );
    await Future<void>.delayed(Duration.zero);

    bookings.dispose();
    provider.dispose();
    notifications.dispose();

    expect(
      realtime.disposeCalls,
      0,
      reason: 'the app owns it and disposes it once, after all three',
    );

    // And the app's own teardown is the single dispose.
    realtime.dispose();
    expect(realtime.disposeCalls, 1);
  });
}

// The repositories are never used by these tests - the controllers are only
// constructed so that they can be disposed - so each is built from a transport
// that fails loudly if it is ever reached. A repository built for real would
// work too; this just makes an accidental dependency impossible to miss.

class _UnusedApiTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async => throw StateError(
    'not used: these tests only exercise disposal ownership',
  );
}

ApiTransport get _unusedApi => _UnusedApiTransport();

BookingRepository _unusedRepository() =>
    BookingRepository(api: _unusedApi, accessToken: () async => 'token');

ProviderRepository _unusedProviderRepository() =>
    ProviderRepository(api: _unusedApi, accessToken: () async => 'token');

NotificationRepository _unusedNotificationRepository() =>
    NotificationRepository(api: _unusedApi, accessToken: () async => 'token');
