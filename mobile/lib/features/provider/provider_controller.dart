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
  ProviderController(this.repository, {this.realtime, this.currentUserId}) {
    _initRealtime();
  }
  final ProviderRepository repository;
  final RealtimeClient? realtime;
  final String? Function()? currentUserId;
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
  final Map<String, DateTime> _lastLocationSentAt = {};
  final Map<String, bool> locationSharing = {};

  DrivingRoute? currentRoute;
  ProviderMapLocation? currentLocation;

  Timer? _locationTimer;
  Timer? _enRouteBroadcastTimer;

  static const Duration _gpsTimeout = Duration(seconds: 8);

  final _incomingRequestsController = StreamController<Map<String, Object?>>.broadcast();
  Stream<Map<String, Object?>> get incomingRequests => _incomingRequestsController.stream;

  void _initRealtime() {
    _realtimeSub = realtime?.projections.listen((projection) {
      if (projection.data['type'] == 'booking.projection-updated.v1') {
        final data = projection.data['data'];
        if (data is! Map) return;
        final bookingId = data['bookingId'];
        if (bookingId is! String) return;
        if (!_isTrackedJob(bookingId)) return;
        final typed = Map<String, Object?>.from(data);
        final newRoute = _parseRoute(typed);
        final newLocation = _parseLocation(typed);
        if (newRoute != null || newLocation != null) {
          if (newRoute != null) currentRoute = newRoute;
          if (newLocation != null) currentLocation = newLocation;
          notifyListeners();
        }
      } else if (projection.data['type'] == 'provider.request.v1') {
        final data = projection.data['data'];
        if (data is Map<String, Object?>) {
          refreshRequests();
          _incomingRequestsController.add(data);
        }
      }
    });
  }

  bool _isTrackedJob(String bookingId) =>
      jobs.any((j) => j.id.toLowerCase() == bookingId.toLowerCase());

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
        currentLocation = ProviderMapLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          capturedAt: position.timestamp,
          receivedAt: DateTime.now(),
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
          currentLocation = ProviderMapLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            capturedAt: position.timestamp,
            receivedAt: DateTime.now(),
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

  void _checkEnRouteBroadcasting() {
    final activeEnRouteJobs = jobs.where(
      (j) => j.status == 'EN_ROUTE' && (locationSharing[j.id] ?? true),
    ).toList();

    if (activeEnRouteJobs.isEmpty) {
      _stopEnRouteBroadcasting();
      return;
    }

    if (_enRouteBroadcastTimer != null && _enRouteBroadcastTimer!.isActive) {
      return;
    }

    for (final job in activeEnRouteJobs) {
      unawaited(publishCurrentLocation(job));
    }

    _enRouteBroadcastTimer = Timer.periodic(const Duration(seconds: 11), (_) async {
      final currentEnRoute = jobs.where(
        (j) => j.status == 'EN_ROUTE' && (locationSharing[j.id] ?? true),
      ).toList();
      if (currentEnRoute.isEmpty) {
        _stopEnRouteBroadcasting();
        return;
      }
      for (final job in currentEnRoute) {
        await publishCurrentLocation(job);
      }
    });
  }

  void _stopEnRouteBroadcasting() {
    _enRouteBroadcastTimer?.cancel();
    _enRouteBroadcastTimer = null;
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
        final userId = currentUserId?.call();
        if (userId != null) {
          realtime?.subscribeAccount(userId);
        }
        availability = await repository.availability();
        if (availability?.status == 'online') {
          await _syncLocationOnce();
          _startLocationTracking();
          _startRequestPolling();
        }
        jobs = await repository.jobs();
        _checkEnRouteBroadcasting();
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
    _checkEnRouteBroadcasting();
    notifyListeners();
    return updated;
  }

  Future<CustomerBooking> cancelJob(CustomerBooking job, String reason) async {
    final updated = await repository.cancelJob(job, reason);
    jobs = jobs.map((item) => item.id == updated.id ? updated : item).toList();
    _checkEnRouteBroadcasting();
    notifyListeners();
    return updated;
  }

  /// On-site adjustment of the job's line items. Returns the updated job,
  /// or null when the backend rejects the change (stale version, payment
  /// already initiated).
  Future<CustomerBooking?> updateJobItems(
    CustomerBooking job,
    List<BookingItemDraft> items,
  ) async {
    try {
      final updated = await repository.updateJobItems(job, items);
      jobs = jobs.map((item) => item.id == updated.id ? updated : item).toList();
      notifyListeners();
      return updated;
    } on ApiException catch (error) {
      actionError = error.statusCode == 409
          ? 'The booking was updated elsewhere or payment already started. Refresh and try again.'
          : 'Services could not be updated. Try again.';
      notifyListeners();
      return null;
    }
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
      _checkEnRouteBroadcasting();
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
      _checkEnRouteBroadcasting();
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

    // The backend rejects ingests within 10s of the previous one. A slow GPS
    // read can make the 11s broadcast tick land inside that window — skipping
    // here costs nothing, burning the cycle on a guaranteed rejection costs a
    // whole update for the customer.
    final lastSent = _lastLocationSentAt[job.id];
    if (lastSent != null &&
        DateTime.now().difference(lastSent) < const Duration(seconds: 10)) {
      return;
    }

    actionError = null;
    _publishingLocation.add(job.id);
    notifyListeners();
    try {
      final sequence = (_locationSequences[job.id] ?? 0) + 1;
      _locationSequences[job.id] = sequence;

      // Ensure presence and consent are recorded before sending coordinates
      await client.subscribeBooking(job.id);
      await client.sendPresence(true);
      await client.sendLocationConsent(
        bookingId: job.id,
        granted: true,
        noticeVersion: '2026-08-13',
      );
      if (locationSharing[job.id] == false) {
        locationPublished.remove(job.id);
        return;
      }
      locationSharing[job.id] = true;

      // Respect an explicit revoke that happened while this publish was in flight.
      if (locationSharing[job.id] != true) return;

      final fix = await _resolveGpsFix();
      if (locationSharing[job.id] != true) return;
      currentLocation = ProviderMapLocation(
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracyMeters: fix.accuracy,
        capturedAt: fix.timestamp,
        receivedAt: DateTime.now(),
      );
      final clampedAccuracy = fix.accuracy > 0
          ? (fix.accuracy > 99.0 ? 99.0 : fix.accuracy)
          : 10.0;
      await client.sendLocation(
        bookingId: job.id,
        sequence: sequence,
        capturedAt: fix.timestamp,
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracyMeters: clampedAccuracy,
      );
      _lastLocationSentAt[job.id] = DateTime.now();
      locationPublished[job.id] = true;
    } on StateError catch (error) {
      actionError = _locationError(error.message.toString());
    } on TimeoutException {
      actionError =
          'Location update timed out. Check your connection and try again.';
    } catch (_) {
      actionError =
          'Your current location could not be sent. Check connection and try again.';
    } finally {
      _publishingLocation.remove(job.id);
      notifyListeners();
    }
  }

  /// The backend rejects fixes coarser than ~100m, so publishing a single
  /// rushed reading often means the customer sees nothing at all. Take up to
  /// two readings and keep the more accurate one; a fresh last-known fix may
  /// beat a poor current one. An old last-known point is never sent — the
  /// server rejects stale captures.
  // ponytail: 100m mirrors the backend LOCATION_MAX_ACCURACY_METERS default;
  // if that env diverges, this threshold needs to follow it.
  static const int _maxFixAccuracyMeters = 100;

  Future<Position> _resolveGpsFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('location-services-disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw StateError('location-permission-missing');
    }
    Position? best = await _tryCurrentPosition();
    if (best == null || best.accuracy > _maxFixAccuracyMeters) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final second = await _tryCurrentPosition();
      if (second != null && (best == null || second.accuracy < best.accuracy)) {
        best = second;
      }
    }
    if (!kIsWeb) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          if (best == null ||
              (DateTime.now().difference(last.timestamp) <=
                      const Duration(seconds: 45) &&
                  last.accuracy < best.accuracy)) {
            best = last;
          }
        }
      } catch (_) {}
    }
    if (best == null) {
      throw StateError('location-fix-unavailable');
    }
    return best;
  }

  Future<Position?> _tryCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? WebSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: _gpsTimeout,
                maximumAge: _gpsTimeout,
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: _gpsTimeout,
              ),
      );
    } catch (_) {
      return null;
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
    'offline' =>
      'Realtime connection is offline. Reconnecting...',
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
    _stopEnRouteBroadcasting();
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

  Future<void> updateLineItems(
    CustomerBooking job,
    List<Map<String, dynamic>> lineItems,
  ) async {
    actionError = null;
    notifyListeners();
    try {
      final updated = await repository.updateLineItems(job.id, lineItems);
      jobs = [updated, ...jobs.where((item) => item.id != updated.id)];
    } on ApiException {
      actionError = 'Could not update extra charges. Try again.';
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
