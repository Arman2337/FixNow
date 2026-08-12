import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:flutter/foundation.dart';

class BookingTrackingController extends ChangeNotifier {
  BookingTrackingController({required this.bookingId, required this.source});
  final String bookingId;
  final BookingTrackingSource source;
  TrackingConnection connection = TrackingConnection.connecting;
  BookingTracking? tracking;
  String? message;

  Future<void> loadSnapshot() async {
    connection = TrackingConnection.reconciling;
    notifyListeners();
    try {
      tracking = await source.fetchSnapshot(bookingId);
      connection = TrackingConnection.live;
      message = null;
    } catch (_) {
      connection = TrackingConnection.offline;
      message = 'Tracking is temporarily unavailable.';
    }
    notifyListeners();
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
}
