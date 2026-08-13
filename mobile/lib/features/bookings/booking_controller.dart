import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:flutter/foundation.dart';

enum BookingListStatus { initial, loading, ready, empty, offline, error }

class BookingController extends ChangeNotifier {
  BookingController(this._repository);
  final BookingRepository _repository;
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
  }
}
