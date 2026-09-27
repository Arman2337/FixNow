import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/notifications/push_api.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Build-time switch for push.
///
/// Defaults to ON. Push used to be opt-in via `--dart-define=PUSH_NOTIFICATIONS_ENABLED=true`,
/// but no run script, IDE run configuration, or documented command ever passed
/// that flag, so the compiled app never initialised Firebase, never obtained a
/// token, and never registered a device. The backend then recorded NO_DEVICES
/// and no tray notification could ever arrive, while the websocket/in-app path
/// kept the app looking healthy whenever it was open.
///
/// Firebase still fails gracefully when a platform has no configuration
/// (see [FirebasePushGateway.ensureInitialized]), so this is safe on web and on
/// any build without google-services.json. Pass
/// `--dart-define=PUSH_NOTIFICATIONS_ENABLED=false` to compile it out.
const bool pushNotificationsEnabled = bool.fromEnvironment(
  'PUSH_NOTIFICATIONS_ENABLED',
  defaultValue: true,
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
  const ForegroundPushMessage({
    required this.title,
    required this.body,
    this.data,
  });

  final String title;
  final String body;
  final Map<String, dynamic>? data;
}

/// Source of pushes that users interact with; separate from [PushGateway] so
/// enrollment fakes stay unaffected.
abstract interface class PushInteractionSource {
  Stream<ForegroundPushMessage> foregroundMessages();
  Stream<ForegroundPushMessage> backgroundInteractions();
  Future<ForegroundPushMessage?> initialInteraction();
}

/// Tokens rotate (reinstall, restore, FCM refresh). Without re-registering, a
/// device that was working silently stops receiving pushes and the stored row
/// points at a dead token.
abstract interface class PushTokenRefresher {
  Stream<String?> tokenRefreshes();
}

class FirebasePushGateway
    implements PushGateway, PushInteractionSource, PushTokenRefresher {
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
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        if (result.isPermanentlyDenied || result.isDenied) {
          return false;
        }
      }
    } catch (_) {}
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      try {
        final status = await Permission.notification.status;
        return status.isGranted;
      } catch (_) {
        return false;
      }
    }
  }

  @override
  Future<String?> currentToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String?> tokenRefreshes() {
    try {
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Both interaction streams used to be built eagerly inside a try/catch.
  /// `FirebaseMessaging.onMessage` throws before `Firebase.initializeApp()` has
  /// run, so the catch returned a permanently empty stream and the foreground
  /// push banner silently never worked. Initialise first, then attach.
  @override
  Stream<ForegroundPushMessage> foregroundMessages() =>
      _afterInit(() => FirebaseMessaging.onMessage);

  @override
  Stream<ForegroundPushMessage> backgroundInteractions() =>
      _afterInit(() => FirebaseMessaging.onMessageOpenedApp);

  Stream<ForegroundPushMessage> _afterInit(
    Stream<RemoteMessage> Function() source,
  ) {
    late final StreamController<ForegroundPushMessage> controller;
    StreamSubscription<RemoteMessage>? subscription;
    controller = StreamController<ForegroundPushMessage>(
      onListen: () async {
        if (!await ensureInitialized()) {
          await controller.close();
          return;
        }
        try {
          subscription = source().listen(
            (message) => controller.add(_convert(message)),
            onError: controller.addError,
          );
        } on Exception catch (error) {
          controller.addError(error);
          await controller.close();
        }
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );
    return controller.stream;
  }

  @override
  Future<ForegroundPushMessage?> initialInteraction() async {
    try {
      final msg = await FirebaseMessaging.instance.getInitialMessage();
      if (msg == null) return null;
      return _convert(msg);
    } catch (_) {
      return null;
    }
  }

  ForegroundPushMessage _convert(RemoteMessage message) {
    final notification = message.notification;
    return ForegroundPushMessage(
      title: notification?.title ?? 'FixNow',
      body: notification?.body ?? '',
      data: message.data,
    );
  }
}

/// FN-062 remainder: show foreground pushes as an in-app banner through the
/// app-wide scaffold messenger. Server copy is policy-owned and already
/// lock-screen-safe, so it is displayed verbatim. Returns the subscription
/// so the app can cancel it on dispose; never subscribes when push is
/// compiled out.
StreamSubscription<ForegroundPushMessage>? bindForegroundPushBanner({
  required PushInteractionSource source,
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
  StreamSubscription<String?>? _tokenRefreshSubscription;

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
        _watchTokenRefresh();
      } on ApiException {
        _update(PushEnrollmentStatus.error);
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Re-register when FCM rotates the token. Without this a reinstall or a
  /// token refresh leaves the backend holding a dead token and delivery stops
  /// with no error anywhere.
  void _watchTokenRefresh() {
    if (_tokenRefreshSubscription != null) return;
    if (_gateway is! PushTokenRefresher) return;
    _tokenRefreshSubscription = (_gateway as PushTokenRefresher)
        .tokenRefreshes()
        .listen((token) async {
          if (token == null || token.length < 32) return;
          try {
            await _api.register(token: token, platform: detectPushPlatform());
            _devices = await _api.list();
            _update(PushEnrollmentStatus.ready);
          } on ApiException {
            _update(PushEnrollmentStatus.error);
          }
        });
  }

  @override
  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
    _tokenRefreshSubscription = null;
    super.dispose();
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
