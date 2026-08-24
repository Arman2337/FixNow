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

  Future<void> load() async {
    status = BookingListStatus.loading;
    notifyListeners();
    try {
      bookings = await _repository.history();
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
          first[index].status != second[index].status)
        return false;
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
    );
    bookings = [...bookings]..[index] = updated;
    notifyListeners();
    unawaited(_subscribeToActiveBooking());
  }

  Future<void> create({
    required String serviceCategoryId,
    required String description,
    required double latitude,
    required double longitude,
  }) async {
    final booking = await _repository.create(
      serviceCategoryId: serviceCategoryId,
      description: description,
      latitude: latitude,
      longitude: longitude,
    );
    bookings = [booking, ...bookings.where((item) => item.id != booking.id)];
    status = BookingListStatus.ready;
    notifyListeners();
    unawaited(_subscribeToActiveBooking());
  }

  Future<CustomerBooking> cancel(CustomerBooking booking, String reason) async {
    final updated = await _repository.cancel(booking: booking, reason: reason);
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
    super.dispose();
  }
}
