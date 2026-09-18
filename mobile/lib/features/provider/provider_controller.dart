import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum ProviderLoadState { loading, ready, failure }

class ProviderController extends ChangeNotifier {
  ProviderController(this.repository, {this.realtime}) {
    _initRealtime();
  }
  final ProviderRepository repository;
  final RealtimeClient? realtime;
  StreamSubscription<RealtimeProjection>? _realtimeSub;
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

  DrivingRoute? currentRoute;
  ProviderMapLocation? currentLocation;

  Timer? _locationTimer;

  void _initRealtime() {
    _realtimeSub = realtime?.projections.listen((projection) {
      if (projection.data['type'] == 'booking.tracking.v1') {
        final data = projection.data['data'];
        if (data is Map<String, Object?>) {
          final newRoute = _parseRoute(data);
          final newLocation = _parseLocation(data);
          if (newRoute != null || newLocation != null) {
            if (newRoute != null) currentRoute = newRoute;
            if (newLocation != null) currentLocation = newLocation;
            notifyListeners();
          }
        }
      }
    });
  }

  DrivingRoute? _parseRoute(Map<String, Object?> data) {
    final route = data['route'];
    if (route is! Map) return null;
    final distance = route['distanceMeters'];
    final duration = route['durationSeconds'];
    final rawCoordinates = route['coordinates'];
    if (distance is! num || duration is! num || rawCoordinates is! List) return null;
    final coordinates = rawCoordinates
        .map((p) {
          if (p is! List || p.length < 2) return null;
          final lng = p[0];
          final lat = p[1];
          if (lng is! num || lat is! num) return null;
          return CustomerMapLocation(latitude: lat.toDouble(), longitude: lng.toDouble());
        })
        .whereType<CustomerMapLocation>()
        .toList();
    if (coordinates.length < 2) return null;
    return DrivingRoute(
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toInt(),
      coordinates: coordinates,
    );
  }

  ProviderMapLocation? _parseLocation(Map<String, Object?> data) {
    if (data['locationAvailability'] != 'live') return null;
    final location = data['location'];
    if (location is! Map) return null;
    final latitude = location['latitude'];
    final longitude = location['longitude'];
    final accuracy = location['accuracyMeters'];
    final capturedAt = DateTime.tryParse(location['capturedAt']?.toString() ?? '');
    final receivedAt = DateTime.tryParse(location['receivedAt']?.toString() ?? '');
    if (latitude is! num || longitude is! num || accuracy is! num || capturedAt == null || receivedAt == null) return null;
    return ProviderMapLocation(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracyMeters: accuracy.toDouble(),
      capturedAt: capturedAt,
      receivedAt: receivedAt,
    );
  }

  Timer? _requestPollingTimer;

  Future<void> _syncLocationOnce() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        profile = await repository.updateLocation(
          position.latitude,
          position.longitude,
        );
      }
    } catch (_) {}
  }

  void _startRequestPolling() {
    _requestPollingTimer?.cancel();
    _requestPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (availability?.status != 'online') return;
      try {
        final newRequests = await repository.availableRequests();
        if (!_areRequestsEqual(requests, newRequests)) {
          requests = newRequests;
          notifyListeners();
        }
        final newJobs = await repository.jobs();
        if (newJobs.length != jobs.length ||
            newJobs.any((nj) => !jobs.any((j) => j.id == nj.id && j.status == nj.status))) {
          jobs = newJobs;
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  void _stopRequestPolling() {
    _requestPollingTimer?.cancel();
    _requestPollingTimer = null;
  }

  bool _areRequestsEqual(List<ProviderRequest> a, List<ProviderRequest> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].version != b[i].version) return false;
    }
    return true;
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          profile = await repository.updateLocation(
            position.latitude,
            position.longitude,
          );
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

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
        if (availability?.status == 'online') {
          await _syncLocationOnce();
          _startLocationTracking();
          _startRequestPolling();
        }
        jobs = await repository.jobs();
        try {
          requests = await repository.availableRequests();
        } catch (_) {
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

  Future<void> submitApplication() async {
    try {
      application = await repository.submitApplication();
      notifyListeners();
    } catch (_) {
      throw Exception('Application could not be submitted. Try again.');
    }
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

  Future<void> removeSkill(String id) async {
    await repository.removeSkill(id);
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
      await _syncLocationOnce();
      _startLocationTracking();
      _startRequestPolling();
      try {
        await refreshRequests();
      } catch (_) {}
    } else {
      _stopLocationTracking();
      _stopRequestPolling();
      requests = const [];
    }
    notifyListeners();
  }

  Future<void> updateSchedule(List<Map<String, Object?>> weeklyRules) async {
    final current = availability;
    if (current == null) return;
    availability = await repository.updateSchedule(
      current: current,
      weeklyRules: weeklyRules,
    );
    notifyListeners();
  }

  Future<void> acceptBooking(String bookingId) async {
    await repository.acceptBooking(bookingId);
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
    final current = jobs.firstWhere((j) => j.id == job.id, orElse: () => job);
    if (client == null ||
        (job.status != 'EN_ROUTE' && current.status != 'EN_ROUTE')) {
      return;
    }
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
      actionError =
          'Location sharing could not start. Check that you are online and try again.';
      notifyListeners();
    }
  }

  Future<void> verifyOtpAndStartJob(CustomerBooking job, String otp) async {
    actionError = null;
    notifyListeners();
    try {
      final updated = await repository.verifyOtpAndStartJob(job, otp);
      jobs = jobs
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    } on ApiException catch (error) {
      actionError = error.statusCode == 403
          ? 'That OTP is incorrect. Ask the customer for the current service-start OTP.'
          : 'Service could not start. Check the OTP and try again.';
    }
    notifyListeners();
  }

  Future<void> publishCurrentLocation(CustomerBooking job) async {
    final client = realtime;
    final current = jobs.firstWhere((j) => j.id == job.id, orElse: () => job);
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
    _realtimeSub?.cancel();
    _stopLocationTracking();
    _stopRequestPolling();
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
