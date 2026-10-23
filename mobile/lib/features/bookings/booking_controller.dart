import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/data/last_good_cache.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter/foundation.dart';

enum BookingListStatus { initial, loading, ready, empty, offline, error }

/// FN-140. The key this controller's snapshot lives under.
const String kBookingHistoryCacheKey = 'bookings';

class BookingController extends ChangeNotifier {
  BookingController(this._repository, {this.realtime, this.cache});
  final BookingRepository _repository;
  BookingRepository get repository => _repository;

  /// Borrowed, not owned. The app creates the socket and disposes it; see the
  /// note in [dispose].
  final RealtimeClient? realtime;

  /// FN-140: optional last-good store. Absent means online-only behaviour, which
  /// is exactly what every caller that does not pass one gets.
  final LastGoodCache? cache;

  StreamSubscription<RealtimeProjection>? _projectionSubscription;
  Timer? _reconciliationTimer;
  BookingListStatus status = BookingListStatus.initial;
  List<CustomerBooking> bookings = const [];

  /// True when [bookings] is a saved copy rather than a live server read.
  /// DESIGN.md §28: the last verified booking state stays visible when the
  /// connection drops, marked with its update time.
  bool isShowingSavedData = false;

  /// When [bookings] was last confirmed by the server. Null unless
  /// [isShowingSavedData].
  DateTime? savedDataAt;

  /// One-shot signal fired when a REQUESTED booking is accepted by a provider
  /// over realtime. The UI reads and clears the value; kept separate from
  /// [notifyListeners] so a shell rebuild can't re-fire the celebration.
  final ValueNotifier<String?> acceptedBooking = ValueNotifier(null);

  Future<void> load() async {
    status = BookingListStatus.loading;
    notifyListeners();
    try {
      final latest = await _repository.history();
      for (final prev in bookings) {
        if (prev.status == 'REQUESTED') {
          final now = latest.where((b) => b.id == prev.id).firstOrNull;
          if (now != null &&
              const {
                'ASSIGNED',
                'EN_ROUTE',
                'IN_PROGRESS',
              }.contains(now.status)) {
            acceptedBooking.value = now.id;
          }
        }
      }
      bookings = latest;
      status = bookings.isEmpty
          ? BookingListStatus.empty
          : BookingListStatus.ready;
      isShowingSavedData = false;
      savedDataAt = null;
      // Notify BEFORE touching storage. A slow or hanging disk must never hold
      // live data off the screen — the snapshot write is bookkeeping, not part
      // of the read the user is waiting for.
      notifyListeners();
      unawaited(_saveSnapshot(latest));
      await _subscribeToActiveBooking();
      return;
    } on ApiException catch (error) {
      final restored = await _showSavedDataIfLostConnection(error);
      if (!restored) status = _statusFor(error);
    } catch (_) {
      final restored = await _showSavedDataIfLostConnection(_offlineFailure);
      if (!restored) status = BookingListStatus.error;
    }
    // One notify for every failure outcome. Returning early from the saved-data
    // path without notifying is what leaves the screen showing its loading
    // skeleton over data that has in fact arrived.
    notifyListeners();
  }

  /// FN-140: replace a lost connection with the last verified server state.
  ///
  /// Only a transport failure qualifies. A 5xx, an auth failure or an
  /// unparseable body means the server answered with something we could not
  /// stand behind, and DESIGN.md §27 requires that to surface as an error
  /// rather than as a plausible-looking cached screen.
  Future<bool> _showSavedDataIfLostConnection(ApiException error) async {
    if (error.kind != ApiFailureKind.offline &&
        error.kind != ApiFailureKind.timeout) {
      return false;
    }
    final cache = this.cache;
    if (cache == null) return false;
    final snapshot = await cache.read(kBookingHistoryCacheKey);
    final data = snapshot?.data;
    if (snapshot == null || data is! List) return false;
    try {
      bookings = data
          .map(
            (row) =>
                CustomerBooking.fromJson(Map<String, Object?>.from(row as Map)),
          )
          .toList(growable: false);
    } catch (_) {
      // A snapshot we cannot parse is not a snapshot we can show.
      return false;
    }
    status = bookings.isEmpty
        ? BookingListStatus.empty
        : BookingListStatus.ready;
    isShowingSavedData = true;
    savedDataAt = snapshot.savedAt;
    // Deliberately no socket subscription: a cached booking has no verified
    // state to stream updates against, and pretending otherwise would show a
    // live-looking card that can never update.
    return true;
  }

  Future<void> _saveSnapshot(List<CustomerBooking> latest) async {
    final cache = this.cache;
    if (cache == null) return;
    await cache.write(
      kBookingHistoryCacheKey,
      latest.map((booking) => booking.toJson()).toList(growable: false),
    );
  }

  static BookingListStatus _statusFor(ApiException error) =>
      error.kind == ApiFailureKind.offline ||
          error.kind == ApiFailureKind.timeout
      ? BookingListStatus.offline
      : BookingListStatus.error;

  /// A transport-shaped failure for the non-[ApiException] path, so an
  /// unexpected throw is treated with the same caution as a real timeout rather
  /// than reaching for the cache with no reason.
  static const ApiException _offlineFailure = ApiException(
    ApiFailureKind.offline,
    'No network connection.',
  );

  Future<void> startRealtime() async {
    if (realtime == null || _projectionSubscription != null) return;
    _projectionSubscription = realtime!.projections.listen(_applyProjection);
    await _subscribeToActiveBooking();
    _reconciliationTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_reconcileActiveBookings()),
    );
  }

  Future<void> _reconcileActiveBookings() async {
    if (!bookings.any(
      (booking) => const {
        'REQUESTED',
        'ASSIGNED',
        'EN_ROUTE',
        'IN_PROGRESS',
      }.contains(booking.status),
    )) {
      return;
    }
    try {
      final latest = await _repository.history();
      if (_sameBookings(latest, bookings)) return;
      for (final prev in bookings) {
        if (prev.status == 'REQUESTED') {
          final now = latest.where((b) => b.id == prev.id).firstOrNull;
          if (now != null &&
              const {
                'ASSIGNED',
                'EN_ROUTE',
                'IN_PROGRESS',
              }.contains(now.status)) {
            acceptedBooking.value = now.id;
          }
        }
      }
      bookings = latest;
      status = latest.isEmpty
          ? BookingListStatus.empty
          : BookingListStatus.ready;
      isShowingSavedData = false;
      savedDataAt = null;
      notifyListeners();
      await _saveSnapshot(latest);
      await _subscribeToActiveBooking();
    } on ApiException {
      // Keep rendering the last authoritative booking state while realtime
      // reconnects; a background retry must never replace the page with error UI.
    }
  }

  static bool _sameBookings(
    List<CustomerBooking> first,
    List<CustomerBooking> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      if (first[index].id != second[index].id ||
          first[index].version != second[index].version ||
          first[index].status != second[index].status) {
        return false;
      }
    }
    return true;
  }

  Future<void> _subscribeToActiveBooking() async {
    final active = bookings.where(
      (item) => const {
        'REQUESTED',
        'ASSIGNED',
        'EN_ROUTE',
        'IN_PROGRESS',
      }.contains(item.status),
    );
    if (active.isEmpty) return;
    await realtime?.subscribeBooking(active.first.id);
  }

  void _applyProjection(RealtimeProjection projection) {
    final id = projection.data['bookingId']?.toString();
    final statusValue = projection.data['status']?.toString();
    final version = (projection.data['sequence'] as num?)?.toInt();
    if (id == null || statusValue == null || version == null) return;
    final index = bookings.indexWhere((booking) => booking.id == id);
    if (index < 0) {
      if (const {'ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS'}.contains(statusValue)) {
        acceptedBooking.value = id;
      }
      unawaited(load());
      return;
    }
    if (version <= bookings[index].version) return;
    if (version > bookings[index].version + 1) {
      if (bookings[index].status == 'REQUESTED' &&
          const {'ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS'}.contains(statusValue)) {
        acceptedBooking.value = id;
      }
      unawaited(load());
      return;
    }
    final current = bookings[index];
    // Items ride along on the projection so an on-site adjustment (version
    // bump without a status change) updates the customer's view live.
    final rawItems = projection.data['items'];
    final items = rawItems is List && rawItems.isNotEmpty
        ? rawItems
              .map(
                (item) => BookingLineItem.fromJson(
                  Map<String, Object?>.from(item as Map),
                ),
              )
              .toList(growable: false)
        : null;
    // The total ships on the same frame as the items. Applying it here is what
    // stops the customer seeing a revised line list next to the old total until
    // the next poll; leaving it out silently showed the pre-adjustment figure.
    final pricing = _parsePricing(projection.data['pricing']);
    final duration = projection.data['estimatedDurationMinutes'];
    final updated = current.copyWith(
      status: statusValue,
      version: version,
      // null keeps the current values (copyWith semantics).
      items: items,
      pricing: pricing,
      estimatedDurationMinutes: duration is int ? duration : null,
    );
    bookings = [...bookings]..[index] = updated;
    if (current.status == 'REQUESTED' &&
        const {'ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS'}.contains(statusValue)) {
      acceptedBooking.value = id;
    }
    notifyListeners();
    unawaited(_subscribeToActiveBooking());
  }

  /// A malformed payload must not tear down the projection stream, so an
  /// unparseable total is treated as "no update" and left to the next poll.
  static BookingPricing? _parsePricing(Object? raw) {
    if (raw is! Map || raw.isEmpty) return null;
    try {
      return BookingPricing.fromJson(Map<String, Object?>.from(raw));
    } on FormatException {
      return null;
    }
  }

  Future<CustomerBooking> create({
    required String serviceCategoryId,
    required String description,
    required double latitude,
    required double longitude,
    DateTime? scheduledAt,
    List<BookingItemDraft>? items,
    String? idempotencyKey,
  }) async {
    final booking = await _repository.create(
      serviceCategoryId: serviceCategoryId,
      description: description,
      latitude: latitude,
      longitude: longitude,
      scheduledAt: scheduledAt,
      items: items,
      idempotencyKey: idempotencyKey,
    );
    bookings = [booking, ...bookings.where((item) => item.id != booking.id)];
    status = BookingListStatus.ready;
    notifyListeners();
    unawaited(_saveSnapshot(bookings));
    unawaited(_subscribeToActiveBooking());
    return booking;
  }

  Future<CustomerBooking> cancel(CustomerBooking booking, String reason) async {
    final updated = await _repository.cancel(booking: booking, reason: reason);
    bookings = bookings
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
    notifyListeners();
    // The stored snapshot now holds a booking the customer has just cancelled.
    // Leaving the old one behind would resurrect it as live-looking history the
    // next time the app opens offline.
    unawaited(_saveSnapshot(bookings));
    return updated;
  }

  Future<CustomerBooking> reschedule({
    required CustomerBooking booking,
    required DateTime newScheduledAt,
    String? reason,
  }) async {
    final updated = await _repository.reschedule(
      booking: booking,
      newScheduledAt: newScheduledAt,
      reason: reason,
    );
    bookings = bookings
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
    notifyListeners();
    unawaited(_saveSnapshot(bookings));
    return updated;
  }

  @override
  void dispose() {
    _reconciliationTimer?.cancel();
    unawaited(_projectionSubscription?.cancel());
    // Does NOT dispose `realtime`. The socket is shared with the provider and
    // notification controllers, and the app owns it. Disposing it here would
    // have been invisible while each feature had its own socket and would have
    // silently killed the other two the moment they shared one - which is
    // exactly the change that makes this a real hazard rather than a latent one.
    acceptedBooking.dispose();
    super.dispose();
  }
}
