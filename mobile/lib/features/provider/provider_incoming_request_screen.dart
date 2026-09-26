import 'dart:async';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _startRinging();
    _subscribeToBookingUpdates();
  }

  Future<void> _startRinging() async {
    try {
      // If we had a ringtone asset, we would play it here.
      // await _audioPlayer.play(AssetSource('audio/ringtone.mp3'));
    } catch (e) {
      debugPrint('Error starting ringtone: $e');
    }
  }

  Future<void> _subscribeToBookingUpdates() async {
    final realtime = widget.providerController.realtime;
    if (realtime == null) return;

    final bookingId = widget.requestData['bookingId'] as String?;
    if (bookingId == null) return;

    await realtime.subscribeBooking(bookingId);
    _subscription = realtime.projections.listen((projection) {
      if (_isDisposed) return;
      final data = projection.data;
      final status = data['status'];
      // If status changes to ASSIGNED (someone else took it) or CANCELLED, dismiss.
      if (status != 'REQUESTED') {
        _dismissScreen();
      }
    });
  }

  void _dismissScreen() {
    if (_isDisposed) return;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _acceptRequest() async {
    if (_isAccepting) return;
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

    await _audioPlayer.stop();
    if (mounted) Navigator.of(context).pop();
  }

  ProviderRequest? _requestFromData() {
    final bookingId = widget.requestData['bookingId'] as String?;
    if (bookingId == null) return null;
    final existing = widget.providerController.requests
        .where((request) => request.id == bookingId)
        .firstOrNull;
    if (existing != null) return existing;

    final version = (widget.requestData['version'] as num?)?.toInt();
    if (version == null) return null;
    return ProviderRequest(
      id: bookingId,
      serviceCategoryId: widget.requestData['serviceCategoryId']?.toString() ?? '',
      description: widget.requestData['description']?.toString() ?? 'Service request',
      createdAt: DateTime.tryParse(widget.requestData['createdAt']?.toString() ?? '') ?? DateTime.now(),
      version: version,
      distanceKm: (widget.requestData['distanceKm'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final description =
        widget.requestData['description']?.toString() ?? 'No description';
    final priceMinor =
        int.tryParse(widget.requestData['priceMinor']?.toString() ?? '0') ?? 0;
    final price = (priceMinor / 100).toStringAsFixed(2);

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
                  color: AppColors.textPrimary,
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
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isAccepting ? null : _acceptRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isAccepting
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
