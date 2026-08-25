import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/emergency/emergency_repository.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:flutter/foundation.dart';

enum EmergencyFlowState { idle, resolvingLocation, creating, dispatched, failed }

/// FN-064: drives the deliberate two-step emergency journey (policy §3).
/// After dispatch it polls the honest wave state every 10 seconds while the
/// UI listens; polling stops on dispose. Push is never the source of truth —
/// this status endpoint is.
class EmergencyController extends ChangeNotifier {
  EmergencyController(this._repository);

  final EmergencyRepository _repository;
  Timer? _pollTimer;

  EmergencyFlowState state = EmergencyFlowState.idle;
  EmergencyCreationResult? creation;
  EmergencyStatusResult? status;
  String? errorMessage;

  bool get showFallback =>
      state == EmergencyFlowState.dispatched && (status?.fallbackRequired ?? false);

  Future<bool> confirmAndDispatch({
    required String serviceCategoryId,
    required String description,
    required BookingLocationProvider locationProvider,
  }) async {
    if (state == EmergencyFlowState.creating) return false;
    state = EmergencyFlowState.resolvingLocation;
    errorMessage = null;
    notifyListeners();

    final BookingLocationFix fix;
    try {
      fix = await locationProvider.resolve();
    } catch (_) {
      return _fail(
        'Location is needed to alert nearby professionals. Enable location and try again.',
      );
    }

    state = EmergencyFlowState.creating;
    notifyListeners();
    try {
      creation = await _repository.create(
        serviceCategoryId: serviceCategoryId,
        description: description,
        latitude: fix.latitude,
        longitude: fix.longitude,
      );
      status = await _repository.status(creation!.bookingId);
      state = EmergencyFlowState.dispatched;
      notifyListeners();
      _startPolling();
      return true;
    } on ApiException catch (failure) {
      return _fail(_friendlyMessage(failure));
    }
  }

  /// One manual/periodic refresh of the honest dispatch state.
  Future<void> refresh() async {
    final id = creation?.bookingId;
    if (id == null || state != EmergencyFlowState.dispatched) return;
    try {
      status = await _repository.status(id);
      notifyListeners();
    } catch (_) {
      // Stale state stays labelled as-is; the next tick retries.
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(refresh());
    });
  }

  bool _fail(String message) {
    state = EmergencyFlowState.failed;
    errorMessage = message;
    notifyListeners();
    return false;
  }

  String _friendlyMessage(ApiException failure) {
    switch (failure.kind) {
      case ApiFailureKind.offline:
      case ApiFailureKind.timeout:
        return 'You appear to be offline. Check your connection and try again.';
      case ApiFailureKind.server:
        return 'The alert could not be sent right now. If this is dangerous, '
            'call your local emergency services and try again in a moment.';
      default:
        return 'The alert could not be sent. Review the details and try again.';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
