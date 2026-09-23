import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter/foundation.dart';

enum BookingListStatus { initial, loading, ready, empty, offline, error }

class BookingController extends ChangeNotifier {
  BookingController(this._repository, {this.realtime});
  final BookingRepository _repository;
  BookingRepository get repository => _repository;
  final RealtimeClient? realtime;
  StreamSubscription<RealtimeProjection>? _projectionSubscription;
  Timer? _reconciliationTimer;
  BookingListStatus status = BookingListStatus.initial;
  List<CustomerBooking> bookings = const [];

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
              const {'ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS'}.contains(now.status)) {
            acceptedBooking.value = now.id;
          }
        }
      }
      bookings = latest;
      status = bookings.isEmpty
          ? BookingListStatus.empty
          : BookingListStatus.ready;
      await _subscribeToActiveBooking();
    } on ApiException catch (error) {
      status =
          error.kind == ApiFailureKind.offline ||
              error.kind == ApiFailureKind.timeout
          ? BookingListStatus.offline
          : BookingListStatus.error;
    } catch (_) {
      status = BookingListStatus.error;
    }
    notifyListeners();
  }

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
              const {'ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS'}.contains(now.status)) {
            acceptedBooking.value = now.id;
          }
        }
      }
      bookings = latest;
      status = latest.isEmpty
          ? BookingListStatus.empty
          : BookingListStatus.ready;
      notifyListeners();
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
    if (index < 0 || version <= bookings[index].version) return;
    if (version > bookings[index].version + 1) {
      if (bookings[index].status == 'REQUESTED' &&
          const {'ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS'}.contains(statusValue)) {
        acceptedBooking.value = id;
      }
      unawaited(load());
      return;
    }
    final current = bookings[index];
    final updated = CustomerBooking(
      id: current.id,
      serviceCategoryId: current.serviceCategoryId,
      status: statusValue,
      description: current.description,
      createdAt: current.createdAt,
      version: version,
      locationLatitude: current.locationLatitude,
      locationLongitude: current.locationLongitude,
      scheduledAt: current.scheduledAt,
    );
    bookings = [...bookings]..[index] = updated;
    if (current.status == 'REQUESTED' &&
        const {'ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS'}.contains(statusValue)) {
      acceptedBooking.value = id;
    }
    notifyListeners();
    unawaited(_subscribeToActiveBooking());
  }

  Future<CustomerBooking> create({
    required String serviceCategoryId,
    required String description,
    required double latitude,
    required double longitude,
    DateTime? scheduledAt,
  }) async {
    final booking = await _repository.create(
      serviceCategoryId: serviceCategoryId,
      description: description,
      latitude: latitude,
      longitude: longitude,
      scheduledAt: scheduledAt,
    );
    bookings = [booking, ...bookings.where((item) => item.id != booking.id)];
    status = BookingListStatus.ready;
    notifyListeners();
    unawaited(_subscribeToActiveBooking());
    return booking;
  }

  Future<CustomerBooking> cancel(CustomerBooking booking, String reason) async {
    final updated = await _repository.cancel(booking: booking, reason: reason);
    bookings = bookings
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
    notifyListeners();
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
    return updated;
  }

  @override
  void dispose() {
    _reconciliationTimer?.cancel();
    unawaited(_projectionSubscription?.cancel());
    realtime?.dispose();
    acceptedBooking.dispose();
    super.dispose();
  }
}
