import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/data/last_good_cache.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_saved_data_banner.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/customer_bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pump_idle.dart';

Map<String, Object?> _bookingJson({
  String id = 'b-1',
  String status = 'EN_ROUTE',
  String description = 'Leaking tap',
}) => {
  'id': id,
  'serviceCategoryId': 'cat-1',
  'status': status,
  'description': description,
  'createdAt': '2026-10-01T09:30:00.000Z',
  'version': 3,
};

/// Named publicly so the analyzer does not flag a private type in a public
/// constructor signature — this fake is the whole point of the file.
class ScriptedApi implements ApiTransport {
  ScriptedApi(this.answers);

  /// Answers are consumed in order per path, so a test can model "offline, then
  /// reconnects" with two entries for the same path. Once a path runs out, its
  /// last answer sticks — a screen that reloads on every build must not
  /// accidentally start succeeding on the second call.
  final List<Answer> answers;
  final Map<String, int> _consumed = {};
  int calls = 0;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    calls += 1;
    final from = _consumed[request.path] ?? 0;
    for (var index = from; index < answers.length; index += 1) {
      if (answers[index].path != request.path) continue;
      _consumed[request.path] = index + 1;
      return _respond(answers[index]);
    }
    Answer? last;
    for (final answer in answers) {
      if (answer.path == request.path) last = answer;
    }
    if (last != null) return _respond(last);
    return const ApiResponse(statusCode: 200, body: {'bookings': <Object?>[]});
  }

  ApiResponse _respond(Answer answer) {
    if (answer.error != null) throw answer.error!;
    return ApiResponse(statusCode: 200, body: answer.body);
  }
}

class Answer {
  const Answer.success(this.path, this.body) : error = null;
  const Answer.fail(this.path, this.error) : body = null;

  final String path;
  final Object? body;
  final ApiException? error;
}

const _offline = ApiException(ApiFailureKind.offline, 'No network connection.');
const _timeout = ApiException(ApiFailureKind.timeout, 'The request timed out.');
const _serverDown = ApiException(ApiFailureKind.server, 'Server unavailable.');

LastGoodCache _cache({DateTime? now}) => LastGoodCache(
  store: MemorySnapshotStore(),
  scope: () => 'user-1',
  clock: () => now ?? DateTime.utc(2026, 10, 8, 12),
);

BookingController _controller(ApiTransport api, LastGoodCache cache) =>
    BookingController(
      BookingRepository(api: api, accessToken: () async => 'token'),
      cache: cache,
    );

void main() {
  group('BookingController offline-first', () {
    test('a successful load records the bookings as last-good data', () async {
      final cache = _cache();
      final controller = _controller(
        ScriptedApi([
          Answer.success('bookings?limit=30', {
            'bookings': [_bookingJson()],
          }),
        ]),
        cache,
      );

      await controller.load();

      expect(controller.isShowingSavedData, isFalse);
      expect(controller.savedDataAt, isNull);
      expect(await cache.read('bookings'), isNotNull);
    });

    test('an offline first launch with no saved data still reports offline', () async {
      final controller = _controller(
        ScriptedApi([Answer.fail('bookings?limit=30', _offline)]),
        _cache(),
      );

      await controller.load();

      expect(controller.status, BookingListStatus.offline);
      expect(controller.bookings, isEmpty);
      expect(controller.isShowingSavedData, isFalse);
    });

    test('an offline launch with saved data renders it, marked as saved', () async {
      final cache = _cache(now: DateTime.utc(2026, 10, 8, 11, 40));
      // First session: online, so the snapshot is written.
      await _controller(
        ScriptedApi([
          Answer.success('bookings?limit=30', {
            'bookings': [_bookingJson()],
          }),
        ]),
        cache,
      ).load();

      // Second session: same account, no network.
      final offlineController = _controller(
        ScriptedApi([Answer.fail('bookings?limit=30', _offline)]),
        cache,
      );
      await offlineController.load();

      expect(offlineController.status, BookingListStatus.ready);
      expect(offlineController.bookings.single.id, 'b-1');
      expect(offlineController.bookings.single.status, 'EN_ROUTE');
      expect(offlineController.isShowingSavedData, isTrue);
      expect(offlineController.savedDataAt, DateTime.utc(2026, 10, 8, 11, 40));
    });

    test('a timeout falls back to saved data too', () async {
      final cache = _cache();
      await _controller(
        ScriptedApi([
          Answer.success('bookings?limit=30', {
            'bookings': [_bookingJson()],
          }),
        ]),
        cache,
      ).load();

      final controller = _controller(
        ScriptedApi([Answer.fail('bookings?limit=30', _timeout)]),
        cache,
      );
      await controller.load();

      expect(controller.status, BookingListStatus.ready);
      expect(controller.isShowingSavedData, isTrue);
    });

    test('a server error is reported as an error, not disguised as saved data',
        () async {
      final cache = _cache();
      await _controller(
        ScriptedApi([
          Answer.success('bookings?limit=30', {
            'bookings': [_bookingJson()],
          }),
        ]),
        cache,
      ).load();

      final controller = _controller(
        ScriptedApi([Answer.fail('bookings?limit=30', _serverDown)]),
        cache,
      );
      await controller.load();

      // DESIGN.md §27: a genuine failure gets its own honest state. Only a lost
      // connection justifies showing a cached copy.
      expect(controller.status, BookingListStatus.error);
      expect(controller.isShowingSavedData, isFalse);
    });

    test('reconnecting replaces saved data with live data', () async {
      final cache = _cache();
      await _controller(
        ScriptedApi([
          Answer.success('bookings?limit=30', {
            'bookings': [_bookingJson()],
          }),
        ]),
        cache,
      ).load();

      final controller = _controller(
        ScriptedApi([
          Answer.fail('bookings?limit=30', _offline),
          Answer.success('bookings?limit=30', {
            'bookings': [_bookingJson(id: 'b-2', status: 'COMPLETED')],
          }),
        ]),
        cache,
      );

      await controller.load();
      expect(controller.isShowingSavedData, isTrue);

      await controller.load();
      expect(controller.isShowingSavedData, isFalse);
      expect(controller.savedDataAt, isNull);
      expect(controller.bookings.single.id, 'b-2');
    });

    test('an unreadable snapshot falls back to the offline state', () async {
      final store = MemorySnapshotStore();
      await store.write(
        'bookings.v1.user-1',
        '{"v":1,"savedAt":"2026-10-08T12:00:00.000Z","data":[{"id":5}]}',
      );
      final controller = _controller(
        ScriptedApi([Answer.fail('bookings?limit=30', _offline)]),
        LastGoodCache(store: store, scope: () => 'user-1'),
      );

      await controller.load();

      expect(controller.status, BookingListStatus.offline);
      expect(controller.isShowingSavedData, isFalse);
    });

    test('a snapshot saved for another account is never shown', () async {
      final store = MemorySnapshotStore();
      await LastGoodCache(store: store, scope: () => 'user-1')
          .write('bookings', [_bookingJson()]);

      final controller = BookingController(
        BookingRepository(
          api: ScriptedApi([Answer.fail('bookings?limit=30', _offline)]),
          accessToken: () async => 'token',
        ),
        cache: LastGoodCache(store: store, scope: () => 'user-2'),
      );

      await controller.load();

      expect(controller.status, BookingListStatus.offline);
      expect(controller.isShowingSavedData, isFalse);
      expect(controller.bookings, isEmpty);
    });

    test('an empty live list is cached as an honest empty state', () async {
      final cache = _cache();
      await _controller(
        ScriptedApi([
          Answer.success('bookings?limit=30', {'bookings': <Object?>[]}),
        ]),
        cache,
      ).load();

      final controller = _controller(
        ScriptedApi([Answer.fail('bookings?limit=30', _offline)]),
        cache,
      );
      await controller.load();

      // "You have no bookings" was the last verified fact, so that is what is
      // shown - with the stamp, not as a fresh live answer.
      expect(controller.status, BookingListStatus.empty);
      expect(controller.bookings, isEmpty);
      expect(controller.isShowingSavedData, isTrue);
    });

    test('cancelling refreshes the stored snapshot', () async {
      final cache = _cache();
      final controller = _controller(
        ScriptedApi([
          Answer.success('bookings?limit=30', {
            'bookings': [_bookingJson()],
          }),
          Answer.success('bookings/b-1/cancel', {
            'booking': _bookingJson(status: 'CANCELLED'),
          }),
        ]),
        cache,
      );
      await controller.load();

      await controller.cancel(
        controller.bookings.single,
        'Booked the wrong slot',
      );

      final stored = await cache.read('bookings');
      expect((stored!.data as List).single['status'], 'CANCELLED');
    });
  });

  group('CustomerBookingsScreen saved-data banner', () {
    testWidgets('shows the stamp above saved bookings and offers a retry', (
      tester,
    ) async {
      final savedAt = DateTime.utc(2026, 10, 8, 11, 40);
      final store = MemorySnapshotStore();
      await LastGoodCache(
        store: store,
        scope: () => 'user-1',
        clock: () => savedAt,
      ).write('bookings', [_bookingJson()]);

      final controller = _controller(
        ScriptedApi([Answer.fail('bookings?limit=30', _offline)]),
        LastGoodCache(store: store, scope: () => 'user-1'),
      );
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CustomerBookingsScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpIdle();

      expect(find.byType(FixSavedDataBanner), findsOneWidget);
      expect(find.text('Showing saved data'), findsOneWidget);
      // The saved booking itself is below the header + stamp, so scroll to it
      // rather than assuming it is in the first viewport.
      await tester.scrollUntilVisible(
        find.text('Leaking tap'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Leaking tap'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpIdle();
      // The retry re-attempts the live read; it must not crash or clear the
      // rendered saved data on failure.
      expect(tester.takeException(), isNull);
      expect(find.text('Showing saved data'), findsOneWidget);
    });

    testWidgets('no banner on a normal live load', (tester) async {
      final controller = _controller(
        ScriptedApi([
          Answer.success('bookings?limit=30', {
            'bookings': [_bookingJson()],
          }),
        ]),
        _cache(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CustomerBookingsScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FixSavedDataBanner), findsNothing);
      expect(find.text('Showing saved data'), findsNothing);
      expect(find.text('Leaking tap'), findsOneWidget);
    });
  });
}