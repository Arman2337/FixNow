import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter/foundation.dart';

enum ProviderLoadState { loading, ready, failure }

class ProviderController extends ChangeNotifier {
  ProviderController(this.repository, {this.realtime});
  final ProviderRepository repository;
  final RealtimeClient? realtime;
  ProviderLoadState state = ProviderLoadState.loading;
  ProviderApplication? application;
  ProviderProfile? profile;
  ProviderAvailability? availability;
  List<CustomerBooking> jobs = const [];
  List<ProviderRequest> requests = const [];
  List<ProviderSkill> skills = const [];
  List<ProviderDocument> documents = const [];
  List<Map<String, Object?>> categories = const [];
  String? errorMessage;
  String? actionError;
  final Map<String, bool> locationPublished = {};
  final Set<String> _publishingLocation = {};
  bool refreshingRequests = false;
  final Map<String, int> _locationSequences = {};
  final Map<String, bool> locationSharing = {};

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
        try {
          requests = await repository.availableRequests();
        } on ApiException {
          requests = const [];
          actionError =
              'Incoming requests are temporarily unavailable. Refresh to try again.';
        }
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
    if (status.toLowerCase() == 'online') {
      try {
        await refreshRequests();
      } catch (_) {}
    } else {
      requests = const [];
    }
    notifyListeners();
  }

  Future<void> setWeekdaySchedule(bool enabled) async {
    final current = availability;
    if (current == null) return;
    availability = await repository.setWeekdaySchedule(current, enabled);
    notifyListeners();
  }

  Future<CustomerBooking?> advanceJob(CustomerBooking job) async {
    final next = switch (job.status) {
      'ASSIGNED' => 'EN_ROUTE',
      'EN_ROUTE' => 'IN_PROGRESS',
      'IN_PROGRESS' => 'COMPLETED',
      _ => null,
    };
    if (next == null) return null;
    final updated = await repository.updateJobStatus(job, next);
    if (next == 'EN_ROUTE') {
      locationSharing[job.id] = true;
    }
    jobs = jobs.map((item) => item.id == updated.id ? updated : item).toList();
    notifyListeners();
    return updated;
  }

  Future<CustomerBooking> cancelJob(CustomerBooking job, String reason) async {
    final updated = await repository.cancelJob(job, reason);
    jobs = jobs.map((item) => item.id == updated.id ? updated : item).toList();
    notifyListeners();
    return updated;
  }

  Future<void> setLocationConsent(CustomerBooking job, bool granted) async {
    final client = realtime;
    final current = jobs.firstWhere(
      (j) => j.id == job.id,
      orElse: () => job,
    );
    if (client == null || (job.status != 'EN_ROUTE' && current.status != 'EN_ROUTE')) return;
    actionError = null;
    try {
      await client.subscribeBooking(job.id);
      await client.sendPresence(true);
      await client.sendLocationConsent(
        bookingId: job.id,
        granted: granted,
        noticeVersion: '2026-08-13',
      );
      locationSharing[job.id] = granted;
      if (!granted) locationPublished.remove(job.id);
      notifyListeners();
      if (granted) await publishCurrentLocation(current);
    } catch (_) {
      actionError = 'Location sharing could not start. Check that you are online and try again.';
      notifyListeners();
    }
  }

  Future<void> verifyOtpAndStartJob(CustomerBooking job, String otp) async {
    actionError = null;
    notifyListeners();
    try {
      final updated = await repository.verifyOtpAndStartJob(job, otp);
      jobs = jobs.map((item) => item.id == updated.id ? updated : item).toList();
    } on ApiException catch (error) {
      actionError = error.statusCode == 403
          ? 'That OTP is incorrect. Ask the customer for the current service-start OTP.'
          : 'Service could not start. Check the OTP and try again.';
    }
    notifyListeners();
  }

  Future<void> publishCurrentLocation(CustomerBooking job) async {
    final client = realtime;
    final current = jobs.firstWhere(
      (j) => j.id == job.id,
      orElse: () => job,
    );
    if (client == null ||
        (job.status != 'EN_ROUTE' && current.status != 'EN_ROUTE') ||
        _publishingLocation.contains(job.id)) {
      return;
    }

    actionError = null;
    _publishingLocation.add(job.id);
    notifyListeners();
    try {
      final sequence = (_locationSequences[job.id] ?? 0) + 1;
      _locationSequences[job.id] = sequence;

      // Always ensure presence and consent are recorded before sending coordinates
      await client.subscribeBooking(job.id);
      await client.sendPresence(true);
      await client.sendLocationConsent(
        bookingId: job.id,
        granted: true,
        noticeVersion: '2026-08-13',
      );
      locationSharing[job.id] = true;

      // User requested: simulate provider ~25 km away from customer location for testing with 2 devices
      double latitude;
      double longitude;
      const double accuracy = 5.0;

      final custLat = current.locationLatitude ?? job.locationLatitude;
      final custLng = current.locationLongitude ?? job.locationLongitude;

      if (custLat != null && custLng != null) {
        // Delta for 25.0 km: deltaLat = 0.187° (~20.8 km), deltaLng = 0.135° (~13.8 km) -> 24.96 km ~ 25 km
        // Smoothly advances 2% closer with each periodic tick
        final progress = ((sequence - 1) * 0.02).clamp(0.0, 0.85);
        final factor = 1.0 - progress;
        latitude = custLat + (0.187 * factor);
        longitude = custLng + (0.135 * factor);
      } else {
        // Fallback default coordinates (Ahmedabad city base + 25km offset)
        latitude = 23.0268278 + 0.187;
        longitude = 73.0698506 + 0.135;
      }

      await client.sendLocation(
        bookingId: job.id,
        sequence: sequence,
        capturedAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracy,
      );
      locationPublished[job.id] = true;
    } on StateError catch (error) {
      actionError = _locationError(error.message.toString());
    } catch (_) {
      actionError =
          'Your current location could not be sent. Check connection and try again.';
    } finally {
      _publishingLocation.remove(job.id);
      notifyListeners();
    }
  }

  bool isPublishingLocation(String bookingId) =>
      _publishingLocation.contains(bookingId);

  static String _locationError(String code) => switch (code) {
    'stale-or-rate-limited' =>
      'Location is already live. Wait 10 seconds before sending another update.',
    'not-authorized' =>
      'Location sharing needs an online provider and an active EN ROUTE job.',
    'invalid-location' =>
      'The browser location was not accurate enough. Try again after updating location.',
    _ => 'Your current location could not be sent. Try again.',
  };

  Future<void> acceptRequest(ProviderRequest request) async {
    actionError = null;
    notifyListeners();
    try {
      final accepted = await repository.acceptRequest(request);
      requests = requests.where((item) => item.id != request.id).toList();
      jobs = [accepted, ...jobs.where((item) => item.id != accepted.id)];
    } on ApiException {
      actionError =
          'That request is no longer available. Refresh to try another.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    realtime?.dispose();
    super.dispose();
  }

  Future<void> refreshRequests() async {
    if (refreshingRequests) return;
    refreshingRequests = true;
    actionError = null;
    notifyListeners();
    try {
      requests = await repository.availableRequests();
    } on ApiException {
      actionError = 'Incoming requests are temporarily unavailable. Try again.';
    } finally {
      refreshingRequests = false;
      notifyListeners();
    }
  }
}
