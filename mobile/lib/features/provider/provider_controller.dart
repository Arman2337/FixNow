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
  List<ProviderSkill> skills = const [];
  List<ProviderDocument> documents = const [];
  List<Map<String, Object?>> categories = const [];
  String? errorMessage;

  Future<void> load({required bool verified}) async {
    state = ProviderLoadState.loading;
    notifyListeners();
    try {
      application = await repository.application();
      profile = await repository.profile();
      skills = await repository.skills();
      categories = await repository.categories();
      documents = verified ? const [] : await repository.documents();
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

  Future<void> saveProfile(ProviderProfile value) async {
    profile = await repository.saveProfile(value);
    notifyListeners();
  }

  Future<void> addSkill(String categoryId) async {
    await repository.addSkill(categoryId);
    skills = await repository.skills();
    notifyListeners();
  }

  Future<void> uploadDocument({
    required String type,
    required String name,
    required String contentType,
    required List<int> bytes,
  }) async {
    await repository.uploadDocument(
      type: type,
      name: name,
      contentType: contentType,
      bytes: bytes,
    );
    documents = await repository.documents();
    notifyListeners();
  }

  Future<void> updateStatus(String status) async {
    final current = availability;
    if (current == null) return;
    availability = await repository.setStatus(current, status);
    notifyListeners();
  }

  Future<void> setWeekdaySchedule(bool enabled) async {
    final current = availability;
    if (current == null) return;
    availability = await repository.setWeekdaySchedule(current, enabled);
    notifyListeners();
  }

  Future<void> advanceJob(CustomerBooking job) async {
    final next = switch (job.status) {
      'ASSIGNED' => 'EN_ROUTE',
      'EN_ROUTE' => 'IN_PROGRESS',
      'IN_PROGRESS' => 'COMPLETED',
      _ => null,
    };
    if (next == null) return;
    final updated = await repository.updateJobStatus(job, next);
    jobs = jobs.map((item) => item.id == updated.id ? updated : item).toList();
    notifyListeners();
  }
}
