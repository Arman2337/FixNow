import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import '../../design_system/app_colors.dart';

class ProviderIncomingRequestScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final ProviderController providerController;

  const ProviderIncomingRequestScreen({
    super.key,
    required this.requestData,
    required this.providerController,
  });

  @override
  State<ProviderIncomingRequestScreen> createState() =>
      _ProviderIncomingRequestScreenState();
}

class _ProviderIncomingRequestScreenState
    extends State<ProviderIncomingRequestScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<RealtimeProjection>? _subscription;
  bool _isDisposed = false;
  bool _isAccepting = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _startRinging();
    _subscribeToBookingUpdates();
    if (_resolvePriceMinor() <= 0) {
      widget.providerController.refreshRequests();
    }
  }

  int _resolvePriceMinor() {
    int priceMinor = 0;
    final rawPrice = widget.requestData['priceMinor'] ??
        widget.requestData['totalAmountMinor'] ??
        widget.requestData['totalMinor'];
    if (rawPrice != null) {
      priceMinor = int.tryParse(rawPrice.toString()) ?? 0;
    }
    if (priceMinor <= 0 && widget.requestData['pricing'] is Map) {
      final pricingMap = widget.requestData['pricing'] as Map;
      priceMinor = (pricingMap['totalMinor'] as num?)?.toInt() ??
          int.tryParse(pricingMap['totalMinor']?.toString() ?? '0') ??
          0;
    }
    final bookingId = widget.requestData['bookingId'] as String? ??
        widget.requestData['id'] as String?;
    if (priceMinor <= 0 && bookingId != null) {
      final existing = widget.providerController.requests
          .where((r) => r.id == bookingId)
          .firstOrNull;
      if (existing?.priceMinor != null && existing!.priceMinor! > 0) {
        priceMinor = existing.priceMinor!;
      }
    }
    return priceMinor;
  }

  Future<void> _startRinging() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/incoming_alert.wav'));
    } catch (e) {
      debugPrint('Error starting ringtone: $e');
    }
  }

  void _cancelNativeNotification() {
    if (!kIsWeb) {
      try {
        const MethodChannel('com.fixnow.mobile/notifications')
            .invokeMethod('cancelIncomingNotification')
            .catchError((_) {});
      } catch (_) {}
    }
  }

  Future<void> _subscribeToBookingUpdates() async {
    final realtime = widget.providerController.realtime;
    if (realtime == null) return;

    final bookingId = widget.requestData['bookingId']?.toString() ??
        widget.requestData['id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return;

    await realtime.subscribeBooking(bookingId);
    _subscription = realtime.projections.listen((projection) {
      if (_isDisposed || _isClosing) return;
      final raw = projection.data;
      final data = (raw['data'] is Map)
          ? Map<String, Object?>.from(raw['data'] as Map)
          : raw;
      final eventBookingId =
          data['bookingId']?.toString() ?? data['id']?.toString();
      if (eventBookingId != null &&
          eventBookingId.toLowerCase() != bookingId.toLowerCase()) {
        return;
      }
      final status = data['status']?.toString();
      // If status transitions away from REQUESTED (e.g. ASSIGNED/CANCELLED), dismiss.
      if (status != null && status != 'REQUESTED') {
        _dismissScreen();
      }
    });
  }

  Future<void> _stopAudioSafely() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  void _closeScreen() {
    if (_isDisposed || _isClosing) return;
    _isClosing = true;
    _cancelNativeNotification();
    unawaited(_stopAudioSafely());
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _dismissScreen() => _closeScreen();

  @override
  void dispose() {
    _isDisposed = true;
    _cancelNativeNotification();
    unawaited(_stopAudioSafely().whenComplete(() {
      try {
        _audioPlayer.dispose();
      } catch (_) {}
    }));
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _acceptRequest() async {
    if (_isAccepting || _isClosing) return;
    final request = _requestFromData();
    if (request == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This request is missing a current version. Refresh and try again.'),
          ),
        );
      }
      return;
    }
    setState(() => _isAccepting = true);

    final accepted = await widget.providerController.acceptRequest(request);
    if (!mounted) return;
    if (!accepted) {
      setState(() => _isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.providerController.actionError ??
              'The request could not be accepted. Refresh and try again.',
          ),
        ),
      );
      return;
    }

    _closeScreen();
  }

  ProviderRequest? _requestFromData() {
    final bookingId = widget.requestData['bookingId']?.toString() ??
        widget.requestData['id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return null;
    final existing = widget.providerController.requests
        .where((request) => request.id == bookingId)
        .firstOrNull;
    if (existing != null) return existing;

    final rawVersion = widget.requestData['version'];
    final version = rawVersion is num
        ? rawVersion.toInt()
        : int.tryParse(rawVersion?.toString() ?? '');
    if (version == null) return null;
    final rawDistance = widget.requestData['distanceKm'];
    final distanceKm = rawDistance is num
        ? rawDistance.toDouble()
        : double.tryParse(rawDistance?.toString() ?? '') ?? 0;
    return ProviderRequest(
      id: bookingId,
      serviceCategoryId: widget.requestData['serviceCategoryId']?.toString() ?? '',
      description: widget.requestData['description']?.toString() ?? 'Service request',
      createdAt: DateTime.tryParse(widget.requestData['createdAt']?.toString() ?? '') ?? DateTime.now(),
      version: version,
      distanceKm: distanceKm,
      priceMinor: _resolvePriceMinor(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final description =
        widget.requestData['description']?.toString() ?? 'No description';
    final bookingId = widget.requestData['bookingId'] as String? ??
        widget.requestData['id'] as String?;
    final acceptInFlight =
        _isAccepting ||
        (bookingId != null &&
            widget.providerController.isAcceptingRequest(bookingId));
    return ListenableBuilder(
      listenable: widget.providerController,
      builder: (context, _) {
        final priceMinor = _resolvePriceMinor();
        final price = (priceMinor / 100).toStringAsFixed(2);
        return _buildBody(
          context,
          description: description,
          price: price,
          acceptInFlight: acceptInFlight,
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required String description,
    required String price,
    required bool acceptInFlight,
  }) {

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'New Request Available',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '₹$price',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _dismissScreen,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: acceptInFlight ? null : _acceptRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: acceptInFlight
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Accept',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
