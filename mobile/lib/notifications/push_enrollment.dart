import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/notifications/push_api.dart';
import 'package:flutter/material.dart';

/// Compile-time gate. Push stays fully inert (no Firebase calls, no native
/// configuration requirement) unless the build explicitly enables it.
const bool pushNotificationsEnabled = bool.fromEnvironment(
  'PUSH_NOTIFICATIONS_ENABLED',
);

/// Platform boundary so enrollment logic is deterministic in tests.
abstract interface class PushGateway {
  Future<bool> ensureInitialized();
  Future<bool> requestPermission();
  Future<String?> currentToken();
}

/// A push delivered while the app is open. Android suppresses tray display
/// for foregrounded apps; the app surfaces these as an in-app banner.
class ForegroundPushMessage {
  const ForegroundPushMessage({required this.title, required this.body});

  final String title;
  final String body;
}

/// Source of foreground-delivered pushes; separate from [PushGateway] so
/// enrollment fakes stay unaffected.
abstract interface class ForegroundPushSource {
  Stream<ForegroundPushMessage> foregroundMessages();
}

class FirebasePushGateway implements PushGateway, ForegroundPushSource {
  bool _initialized = false;

  @override
  Future<bool> ensureInitialized() async {
    if (_initialized) return true;
    try {
      await Firebase.initializeApp();
      _initialized = true;
      return true;
    } on Exception {
      // Missing platform configuration (google-services.json / web options)
      // lands here. The UI reports notifications as honestly unavailable.
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> currentToken() => FirebaseMessaging.instance.getToken();

  @override
  Stream<ForegroundPushMessage> foregroundMessages() =>
      FirebaseMessaging.onMessage.map((message) {
        final notification = message.notification;
        return ForegroundPushMessage(
          title: notification?.title ?? 'FixNow',
          body: notification?.body ?? '',
        );
      });
}

/// FN-062 remainder: show foreground pushes as an in-app banner through the
/// app-wide scaffold messenger. Server copy is policy-owned and already
/// lock-screen-safe, so it is displayed verbatim. Returns the subscription
/// so the app can cancel it on dispose; never subscribes when push is
/// compiled out.
StreamSubscription<ForegroundPushMessage>? bindForegroundPushBanner({
  required ForegroundPushSource source,
  required GlobalKey<ScaffoldMessengerState> messengerKey,
  bool featureEnabled = pushNotificationsEnabled,
}) {
  if (!featureEnabled) return null;
  return source.foregroundMessages().listen((message) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('${message.title} — ${message.body}')),
    );
  });
}

enum PushEnrollmentStatus {
  /// Build was compiled without push support.
  disabled,

  /// Firebase is unavailable on this device/configuration.
  unavailable,

  /// Known state with the current device list.
  ready,

  /// The OS permission request was declined.
  permissionDenied,

  /// Registration or listing failed.
  error,
}

class PushEnrollmentController extends ChangeNotifier {
  PushEnrollmentController({
    required PushApi api,
    PushGateway? gateway,
    bool featureEnabled = pushNotificationsEnabled,
  }) : _api = api,
       _gateway = gateway ?? FirebasePushGateway(),
       _featureEnabled = featureEnabled {
    if (!_featureEnabled) {
      _status = PushEnrollmentStatus.disabled;
    }
  }

  final PushApi _api;
  final PushGateway _gateway;
  final bool _featureEnabled;

  PushEnrollmentStatus _status = PushEnrollmentStatus.ready;
  List<PushDeviceSummary> _devices = const [];
  bool _busy = false;

  PushEnrollmentStatus get status => _status;
  List<PushDeviceSummary> get devices => _devices;

  /// True while any enrollment action is running.
  bool get busy => _busy;

  bool get canEnable =>
      !_busy &&
      (_status == PushEnrollmentStatus.ready ||
          _status == PushEnrollmentStatus.permissionDenied ||
          _status == PushEnrollmentStatus.error);

  void _update(PushEnrollmentStatus status) {
    _status = status;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!_featureEnabled || _busy) return;
    _busy = true;
    notifyListeners();
    try {
      if (!await _gateway.ensureInitialized()) {
        _update(PushEnrollmentStatus.unavailable);
        return;
      }
      try {
        _devices = await _api.list();
        _update(PushEnrollmentStatus.ready);
      } on ApiException catch (failure) {
        _update(
          failure.kind == ApiFailureKind.offline
              ? PushEnrollmentStatus.error
              : PushEnrollmentStatus.unavailable,
        );
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Explicit user consent point: requests OS permission, obtains the FCM
  /// token, and registers it with the backend.
  Future<void> enable() async {
    if (!_featureEnabled || _busy) return;
    _busy = true;
    notifyListeners();
    try {
      if (!await _gateway.ensureInitialized()) {
        _update(PushEnrollmentStatus.unavailable);
        return;
      }
      if (!await _gateway.requestPermission()) {
        _update(PushEnrollmentStatus.permissionDenied);
        return;
      }
      final token = await _gateway.currentToken();
      if (token == null || token.length < 32) {
        _update(PushEnrollmentStatus.unavailable);
        return;
      }
      try {
        await _api.register(token: token, platform: detectPushPlatform());
        _devices = await _api.list();
        _update(PushEnrollmentStatus.ready);
      } on ApiException {
        _update(PushEnrollmentStatus.error);
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> disable(PushDeviceSummary device) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await _api.revoke(device.id);
      await refresh();
    } on ApiException {
      _update(PushEnrollmentStatus.error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
