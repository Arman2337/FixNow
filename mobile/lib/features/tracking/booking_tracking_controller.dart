import 'dart:async';

import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter/foundation.dart';

class BookingTrackingController extends ChangeNotifier {
  BookingTrackingController({
    required this.bookingId,
    required this.source,
    this.realtime,
  });
  final String bookingId;
  final BookingTrackingSource source;
  final RealtimeClient? realtime;
  StreamSubscription<RealtimeProjection>? _projectionSubscription;
  TrackingConnection connection = TrackingConnection.connecting;
  BookingTracking? tracking;
  String? message;

  Future<void> loadSnapshot() async {
    connection = TrackingConnection.reconciling;
    notifyListeners();
    try {
      tracking = await source.fetchSnapshot(bookingId);
      _projectionSubscription ??= realtime?.projections.listen(
        _applyProjection,
      );
      await realtime?.subscribeBooking(bookingId);
      connection = TrackingConnection.live;
      message = null;
    } catch (_) {
      connection = TrackingConnection.offline;
      message = 'Tracking is temporarily unavailable.';
    }
    notifyListeners();
  }

  Future<void> _applyProjection(RealtimeProjection projection) async {
    final data = projection.data;
    final next = BookingTracking(
      bookingId: data['bookingId']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      sequence: (data['sequence'] as num?)?.toInt() ?? 0,
      locationAvailability: switch (data['locationAvailability']) {
        'live' => LocationAvailability.live,
        'stale' => LocationAvailability.stale,
        _ => LocationAvailability.unavailable,
      },
      estimatedMinutes: ((data['eta'] as Map?)?['estimatedMinutes'] as num?)
          ?.toInt(),
    );
    await applyRealtime(next);
  }

  Future<void> reconnect() => loadSnapshot();

  Future<void> applyRealtime(BookingTracking next) async {
    final current = tracking;
    if (next.bookingId != bookingId ||
        (current != null && next.sequence <= current.sequence)) {
      return;
    }
    if (current != null && next.sequence > current.sequence + 1) {
      await loadSnapshot();
      return;
    }
    tracking = next;
    connection = TrackingConnection.live;
    message = null;
    notifyListeners();
  }

  void markDisconnected() {
    connection = TrackingConnection.offline;
    message = 'Updates paused. Last known booking status is shown.';
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_projectionSubscription?.cancel());
    realtime?.dispose();
    super.dispose();
  }
}
