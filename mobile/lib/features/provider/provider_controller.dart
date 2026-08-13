import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:flutter/foundation.dart';

enum ProviderLoadState { loading, ready, failure }

class ProviderController extends ChangeNotifier {
  ProviderController(this.repository);
  final ProviderRepository repository;
  ProviderLoadState state = ProviderLoadState.loading;
  ProviderApplication? application;
  ProviderProfile? profile;
  ProviderAvailability? availability;
  List<CustomerBooking> jobs = const [];
  String? errorMessage;

  Future<void> load({required bool verified}) async {
    state = ProviderLoadState.loading;
    notifyListeners();
    try {
      application = await repository.application();
      profile = await repository.profile();
      if (verified) {
        availability = await repository.availability();
        jobs = await repository.jobs();
      }
      state = ProviderLoadState.ready;
    } on ApiException {
      errorMessage = 'Provider details could not be loaded. Try again.';
      state = ProviderLoadState.failure;
    }
    notifyListeners();
  }

  Future<void> updateStatus(String status) async {
    final current = availability;
    if (current == null) return;
    availability = await repository.setStatus(current, status);
    notifyListeners();
  }
}
