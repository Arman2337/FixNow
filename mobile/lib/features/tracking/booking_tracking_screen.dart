import 'dart:async';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_banner.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
import 'package:fixnow_mobile/features/call/booking_call_screen.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/call/call_session.dart';
import 'package:fixnow_mobile/features/call/incoming_call_dialog.dart';
import 'package:fixnow_mobile/features/chat/booking_chat_screen.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_controller.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';
import 'package:flutter/material.dart';

class BookingTrackingScreen extends StatefulWidget {
  const BookingTrackingScreen({
    required this.controller,
    this.chatRepository,
    this.callRepository,
    this.onOpenChat,
    this.onCallPressed,
    super.key,
  });
  final BookingTrackingController controller;
  final ChatRepository? chatRepository;
  final CallRepository? callRepository;
  final void Function(BuildContext context, String bookingId)? onOpenChat;
  final void Function(BuildContext context, String bookingId)? onCallPressed;
  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen> {
  StreamSubscription<RealtimeProjection>? _callSub;

  @override
  void initState() {
    super.initState();
    widget.controller.loadSnapshot();
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    _callSub = widget.controller.realtime?.projections.listen((p) {
      final type = p.data['type']?.toString();
      final data = p.data['data'];
      if (type == 'call.incoming.v1' && data is Map) {
        final session = CallSession.fromJson(Map<String, Object?>.from(data));
        if (session.callerRole != 'CUSTOMER' &&
            widget.callRepository != null &&
            mounted) {
          IncomingCallDialog.show(
            context,
            session: session,
            repository: widget.callRepository!,
            realtimeClient: widget.controller.realtime,
            callerTitle: 'Service Technician',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.small),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuD5p30JJ4xla5t1sty9n4wk388rQJ8NTT4EVcQxwUkSFFNIabrf8QeAkkMc_rR4nuu7D6NP0MuNneeDoe95jDDpkzWZuV_F6vdYLId2wTwZIKy2HNSuIHxxja5Itw6TGA59DzYezKUsdbqYWMwbL2MbodCGE8XidOaalteI9sNNNKeq_99u5vxzR83Qhaz4mgw7LMydMp-BCoX3lJLI40C5cAkXkr6A8wPRILlCbD06LufFnfkxVtitHj9urdIYeJ6iuw',
                ),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Live Technician Tracker',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          tooltip: 'Emergency SOS',
          icon: const Icon(Icons.emergency_rounded, color: AppColors.error),
          onPressed: () {
            showFixBanner(
              ScaffoldMessenger.of(context),
              message: 'FixNow Safety Support is standing by for active jobs.',
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: IconButton(
            icon: const CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuC0fmQVzMF5Rs9tsmYYciE22juYHedjg4xdlfgpeJPLo_c1OH5vKW5FLwDdjmHCgNS-Zm04HM19nUNHjXKazC-ERm-09PmmZ0t9UWKgl0gtW4zPyDcckAwqOOpRtUJdKiGmku0L4h6pmM0GiXa759mhV3h7fANwBjZo0KlBPO2SgZkWyhJxMDMSi3gO97TQEsINn0kH5QyO1t3odNW--r6DJcOlfWCxmP59GEpDHwjKHWxZsj55b2Sa',
              ),
            ),
            onPressed: () {},
          ),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _ConnectionCard(controller: widget.controller),
          _TrackingCard(tracking: widget.controller.tracking),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                if (widget.controller.tracking?.serviceStartOtp
                    case final otp?) ...[
                  _buildSecurityOtpCard(otp),
                  const SizedBox(height: AppSpacing.md),
                ],
                _buildSpecialistProfileCard(context),
                const SizedBox(height: AppSpacing.md),
                _buildStatusTimelineCard(context),
                const SizedBox(height: AppSpacing.md),
                _buildServiceSummaryCard(context),
                const SizedBox(height: AppSpacing.md),
                _buildContextualActions(context),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSecurityOtpCard(String otp) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'FixNow Secure Start',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Text(
                  'Keep Confidential',
                  style: TextStyle(
                    color: AppColors.onSecondaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Column(
              children: [
                const Text(
                  'SERVICE START CODE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        otp.split('').join(' '),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        showFixBanner(
                          ScaffoldMessenger.of(context),
                          message: 'OTP Copied to clipboard',
                        );
                      },
                      icon: const Icon(
                        Icons.content_copy_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share this 4-digit code with the specialist upon arrival to begin work safely.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialistProfileCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuC0fmQVzMF5Rs9tsmYYciE22juYHedjg4xdlfgpeJPLo_c1OH5vKW5FLwDdjmHCgNS-Zm04HM19nUNHjXKazC-ERm-09PmmZ0t9UWKgl0gtW4zPyDcckAwqOOpRtUJdKiGmku0L4h6pmM0GiXa759mhV3h7fANwBjZo0KlBPO2SgZkWyhJxMDMSi3gO97TQEsINn0kH5QyO1t3odNW--r6DJcOlfWCxmP59GEpDHwjKHWxZsj55b2Sa',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: AppColors.onPrimary,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Rahul K.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixedDim.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Pro',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Senior Certified Electrician',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.tertiary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '4.93',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '(1,420 jobs)',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(
                          Icons.badge_rounded,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Aadhaar & Trade Verified',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startCall(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text(
                    'Call Rahul',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openChat(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainer,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                  icon: const Icon(
                    Icons.chat_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  label: const Text(
                    'Chat',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.quickreply_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Rahul: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '"I am approaching your gate."',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Just now',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimelineCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Booking Status',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Order #FX-${widget.controller.bookingId.substring(0, 5).toUpperCase()}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FixTimeline(
            currentStatus: widget.controller.tracking?.status ?? 'REQUESTED',
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSummaryCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Service Summary',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Text(
                '₹449',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Standard Inspection & Diagnosis',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₹299',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Emergency Dispatch Convenience Fee',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₹150',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.borderDefault, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FixNow 30-Day Guarantee',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Included FREE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'BOOKING CONTROLS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerLowest,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
                icon: const Icon(
                  Icons.update_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                label: const Text(
                  'Reschedule',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showSafetyModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerLowest,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
                icon: const Icon(
                  Icons.health_and_safety_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                label: const Text(
                  'Safety Guide',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    showFixBanner(
                      ScaffoldMessenger.of(context),
                      message:
                          'Booking cancellation initiated. No fee was applied.',
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    backgroundColor: AppColors.error.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                  ),
                  icon: const Icon(Icons.cancel_rounded, size: 18),
                  label: const Text(
                    'Cancel Booking',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Cancellation is free for another '),
                    TextSpan(
                      text: '3 minutes',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text:
                          '. A ₹99 technician dispatch fee applies thereafter.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSafetyModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Safety Protocols',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildSafetyRule(
                  Icons.badge_rounded,
                  'Verify Physical ID Badge',
                  'Match Rahul\'s face and official FixNow lanyard credentials prior to doorway entry.',
                ),
                const SizedBox(height: AppSpacing.md),
                _buildSafetyRule(
                  Icons.pin_rounded,
                  'Do Not Disclose OTP Early',
                  'Only provide code 4821 once the technician is physically present at the circuit breaker or appliance.',
                ),
                const SizedBox(height: AppSpacing.md),
                _buildSafetyRule(
                  Icons.lock_rounded,
                  'In-App Digital Payments Only',
                  'Never settle with cash outside the platform. All guarantees require FixNow in-app escrow billing.',
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                    child: const Text(
                      'I Understand',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSafetyRule(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openChat(BuildContext context) {
    final bookingId =
        widget.controller.tracking?.bookingId ?? widget.controller.bookingId;

    if (widget.onOpenChat != null) {
      widget.onOpenChat!(context, bookingId);
      return;
    }

    if (widget.chatRepository != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingChatScreen(
            controller: ChatController(
              bookingId: bookingId,
              repository: widget.chatRepository!,
              realtimeClient: widget.controller.realtime,
            ),
            callRepository: widget.callRepository,
            onCallPressed: () => _startCall(context),
          ),
        ),
      );
      return;
    }

    showFixBanner(
      ScaffoldMessenger.of(context),
      message: 'In-app messaging for active bookings is active.',
    );
  }

  void _startCall(BuildContext context) {
    final bookingId =
        widget.controller.tracking?.bookingId ?? widget.controller.bookingId;

    if (widget.onCallPressed != null) {
      widget.onCallPressed!(context, bookingId);
      return;
    }

    if (widget.callRepository != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingCallScreen(
            controller: CallController(
              bookingId: bookingId,
              repository: widget.callRepository!,
              realtimeClient: widget.controller.realtime,
              initialSpeakerOn: true,
            ),
          ),
        ),
      );
      return;
    }

    showFixBanner(
      ScaffoldMessenger.of(context),
      message: 'In-app audio calling connecting...',
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.controller});
  final BookingTrackingController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.connection == TrackingConnection.live) {
      return const SizedBox.shrink();
    }
    final loading = controller.connection != TrackingConnection.offline;
    return FixCard(
      semanticLabel: loading
          ? 'Refreshing booking tracking'
          : 'Tracking updates paused',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loading ? 'Refreshing updates' : 'Updates paused',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textOnLightPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            loading
                ? 'Confirming the latest booking status.'
                : controller.message ?? 'Live updates are unavailable.',
          ),
          if (!loading) ...[
            const SizedBox(height: AppSpacing.lg),
            FixButton(
              label: 'Try again',
              onPressed: controller.reconnect,
              variant: FixButtonVariant.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.tracking});
  final BookingTracking? tracking;

  @override
  Widget build(BuildContext context) {
    final value = tracking;
    if (value == null) return const SizedBox.shrink();

    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        children: [
          // Map Canvas
          if (value.providerLocation != null || value.customerLocation != null)
            Positioned.fill(
              child: ProviderLiveMap(
                providerLocation: value.providerLocation,
                customerLocation: value.customerLocation,
                route: value.route,
                estimatedMinutes: value.estimatedMinutes,
                distanceKm: value.route == null
                    ? null
                    : value.route!.distanceMeters / 1000,
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: AppColors.surfaceContainerHigh,
                child: const Center(
                  child: Text(
                    'Map unavailable',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),

          // Floating Live ETA Badge Overlay
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest.withValues(
                      alpha: 0.9,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Live Tracking',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          'GPS Active',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest.withValues(
                      alpha: 0.9,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Live ETA Summary Bar
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: const Icon(
                          Icons.timer_rounded,
                          color: AppColors.onPrimaryFixed,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'ESTIMATED ARRIVAL',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                value.estimatedMinutes == null
                                    ? '--'
                                    : '${value.estimatedMinutes} mins',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                value.route != null
                                    ? '(${(value.route!.distanceMeters / 1000).toStringAsFixed(1)} km away)'
                                    : '',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Traffic Flow',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 6, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Clear Road',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
