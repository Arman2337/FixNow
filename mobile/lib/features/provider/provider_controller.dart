import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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

  Future<CustomerBooking> cancelJob(CustomerBooking job, String reason) async {
    final updated = await repository.cancelJob(job, reason);
    jobs = jobs.map((item) => item.id == updated.id ? updated : item).toList();
    notifyListeners();
    return updated;
  }

  Future<void> setLocationConsent(CustomerBooking job, bool granted) async {
    final client = realtime;
    if (client == null || job.status != 'EN_ROUTE') return;
    await client.subscribeBooking(job.id);
    await client.sendPresence(true);
    await client.sendLocationConsent(
      bookingId: job.id,
      granted: granted,
      noticeVersion: '2026-08-13',
    );
    locationSharing[job.id] = granted;
    notifyListeners();
  }

  Future<void> publishCurrentLocation(CustomerBooking job) async {
    final client = realtime;
    if (client == null || job.status != 'EN_ROUTE') {
      print('publishCurrentLocation aborted: client is null or job not EN_ROUTE');
      return;
    }
    
    try {
      print('Requesting current position from browser...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      print('Position obtained: ${position.latitude}, ${position.longitude}');

      final sequence = (_locationSequences[job.id] ?? 0) + 1;
      _locationSequences[job.id] = sequence;
      
      print('Connecting and subscribing to booking ${job.id}...');
      await client.subscribeBooking(job.id);
      
      print('Sending presence...');
      await client.sendPresence(true);
      
      print('Sending location update...');
      await client.sendLocation(
        bookingId: job.id,
        sequence: sequence,
        capturedAt: position.timestamp,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
      print('Location update completely sent!');
    } catch (e, stack) {
      print('Error in publishCurrentLocation: $e');
      print(stack);
    }
  }

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
