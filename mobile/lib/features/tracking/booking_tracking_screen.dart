import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/cancellation_dialog.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_banner.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
import 'package:fixnow_mobile/features/chat/booking_chat_screen.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_controller.dart';
import 'package:fixnow_mobile/features/tracking/provider_live_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BookingTrackingScreen extends StatefulWidget {
  const BookingTrackingScreen({
    required this.controller,
    this.chatRepository,
    this.onOpenChat,
    this.onCallPressed,
    this.onCancel,
    this.onReschedule,
    this.onOpenProfile,
    super.key,
  });
  final BookingTrackingController controller;
  final ChatRepository? chatRepository;
  final void Function(BuildContext context, String bookingId)? onOpenChat;
  final void Function(BuildContext context, String bookingId)? onCallPressed;
  final Future<CustomerBooking> Function(String reason)? onCancel;
  final VoidCallback? onReschedule;
  final VoidCallback? onOpenProfile;
  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen> {
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    widget.controller.loadSnapshot();
  }

  @override
  void dispose() {
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
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuD5p30JJ4xla5t1sty9n4wk388rQJ8NTT4EVcQxwUkSFFNIabrf8QeAkkMc_rR4nuu7D6NP0MuNneeDoe95jDDpkzWZuV_F6vdYLId2wTwZIKy2HNSuIHxxja5Itw6TGA59DzYezKUsdbqYWMwbL2MbodCGE8XidOaalteI9sNNNKeq_99u5vxzR83Qhaz4mgw7LMydMp-BCoX3lJLI40C5cAkXkr6A8wPRILlCbD06LufFnfkxVtitHj9urdIYeJ6iuw',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Live Technician Tracker',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
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
          child: widget.onOpenProfile == null
              ? CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primarySoft,
                  child: const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                )
              : IconButton(
                  tooltip: 'Open profile',
                  icon: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primarySoft,
                    backgroundImage: const NetworkImage(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuC0fmQVzMF5Rs9tsmYYciE22juYHedjg4xdlfgpeJPLo_c1OH5vKW5FLwDdjmHCgNS-Zm04HM19nUNHjXKazC-ERm-09PmmZ0t9UWKgl0gtW4zPyDcckAwqOOpRtUJdKiGmku0L4h6pmM0GiXa759mhV3h7fANwBjZo0KlBPO2SgZkWyhJxMDMSi3gO97TQEsINn0kH5QyO1t3odNW--r6DJcOlfWCxmP59GEpDHwjKHWxZsj55b2Sa',
                    ),
                    onBackgroundImageError: (_, _) {},
                    child: const Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  onPressed: widget.onOpenProfile,
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
                      tooltip: 'Copy service-start OTP',
                      onPressed: () => _copyOtp(otp),
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
    final providerName =
        widget.controller.tracking?.providerName ?? 'Verified Specialist';
    final providerFirstName = providerName.split(' ').first;

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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuC0fmQVzMF5Rs9tsmYYciE22juYHedjg4xdlfgpeJPLo_c1OH5vKW5FLwDdjmHCgNS-Zm04HM19nUNHjXKazC-ERm-09PmmZ0t9UWKgl0gtW4zPyDcckAwqOOpRtUJdKiGmku0L4h6pmM0GiXa759mhV3h7fANwBjZo0KlBPO2SgZkWyhJxMDMSi3gO97TQEsINn0kH5QyO1t3odNW--r6DJcOlfWCxmP59GEpDHwjKHWxZsj55b2Sa',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
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
                        Flexible(
                          child: Text(
                            widget.controller.tracking?.providerName ??
                                'Provider details unavailable',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                      'Provider verification details',
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
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.controller.tracking?.providerRating !=
                                          null
                                      ? widget
                                            .controller
                                            .tracking!
                                            .providerRating!
                                            .toStringAsFixed(1)
                                      : 'Rating unavailable',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget
                                              .controller
                                              .tracking
                                              ?.providerJobsCount !=
                                          null
                                      ? '(${widget.controller.tracking!.providerJobsCount} jobs)'
                                      : 'Job history unavailable',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Verification details are available in the booking record.',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final stackActions =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final callAction = ElevatedButton.icon(
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
                label: Text(
                  'Call $providerFirstName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
              final chatAction = ElevatedButton.icon(
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
              );
              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    callAction,
                    const SizedBox(height: AppSpacing.sm),
                    chatAction,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: callAction),
                  const SizedBox(width: 10),
                  Expanded(child: chatAction),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.quickreply_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$providerFirstName: ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const TextSpan(
                          text: '"I am approaching your location."',
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
            children: [
              const Expanded(
                child: Text(
                  'Booking Status',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Order #FX-${widget.controller.bookingId.substring(0, 5).toUpperCase()}',
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
    final tracking = widget.controller.tracking;
    final items = tracking?.items ?? const <BookingLineItem>[];
    final pricing = tracking?.pricing;

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
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Service Summary',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Server-computed total, GST included. Was a hardcoded "₹449"
              // that had no relationship to the booking.
              Text(
                pricing?.formattedTotal ?? '—',
                style: TextStyle(
                  color: pricing == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
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
            child: Column(
              children: [
                if (items.isEmpty)
                  // Honest absence beats an invented breakdown.
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'No itemised services on this booking yet. Your '
                      'professional will confirm the work and the exact amount '
                      'before the job is closed.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )
                else ...[
                  for (var i = 0; i < items.length; i++) ...[
                    _buildSummaryRow(items[i]),
                    if (i != items.length - 1) const SizedBox(height: 8),
                  ],
                  if (pricing != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: AppColors.borderDefault, height: 1),
                    ),
                    _buildSummaryRow(
                      BookingLineItem(
                        id: 'subtotal',
                        name: 'Subtotal',
                        quantity: 1,
                        unitPriceMinor: pricing.subtotalMinor,
                      ),
                      emphasise: false,
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      BookingLineItem(
                        id: 'gst',
                        name: 'GST (18%)',
                        quantity: 1,
                        unitPriceMinor: pricing.gstMinor,
                      ),
                      emphasise: false,
                    ),
                  ],
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.borderDefault, height: 1),
                ),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'FixNow 30-Day Guarantee',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'Included FREE',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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

  static String _money(int minor) =>
      '₹${(minor / 100).toStringAsFixed(minor % 100 == 0 ? 0 : 2)}';

  Widget _buildSummaryRow(BookingLineItem item, {bool emphasise = true}) {
    final label = item.quantity == 1
        ? item.name
        : '${item.name} ×${item.quantity}';
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: emphasise ? AppColors.textSecondary : AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          _money(item.lineTotalMinor),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: emphasise ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
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
        LayoutBuilder(
          builder: (context, constraints) {
            final stackActions =
                constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final rescheduleAction = ElevatedButton.icon(
              onPressed: widget.onReschedule,
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
            );
            final safetyAction = ElevatedButton.icon(
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
            );
            if (stackActions) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.onReschedule != null) ...[
                    rescheduleAction,
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  safetyAction,
                ],
              );
            }
            return Row(
              children: [
                if (widget.onReschedule != null) ...[
                  Expanded(child: rescheduleAction),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(child: safetyAction),
              ],
            );
          },
        ),
        if (widget.onCancel != null &&
            const {
              'REQUESTED',
              'ASSIGNED',
            }.contains(widget.controller.tracking?.status)) ...[
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
                    onPressed: _isCancelling ? null : _cancelBooking,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      backgroundColor: AppColors.error.withValues(alpha: 0.05),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                    ),
                    icon: _isCancelling
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_rounded, size: 18),
                    label: Text(
                      _isCancelling ? 'Cancelling...' : 'Cancel Booking',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _copyOtp(String otp) async {
    try {
      await Clipboard.setData(ClipboardData(text: otp));
      if (mounted) {
        showFixBanner(
          ScaffoldMessenger.of(context),
          message: 'OTP copied to clipboard',
        );
      }
    } on Object {
      if (mounted) {
        showFixBanner(
          ScaffoldMessenger.of(context),
          message: 'The OTP could not be copied. Try again.',
        );
      }
    }
  }

  Future<void> _cancelBooking() async {
    if (widget.onCancel == null || _isCancelling) return;
    final reason = await showCancellationDialog(context);
    if (reason == null || !mounted) return;
    setState(() => _isCancelling = true);
    try {
      await widget.onCancel!(reason);
      if (mounted) {
        showFixBanner(
          ScaffoldMessenger.of(context),
          message: 'Booking cancelled successfully',
        );
      }
    } on Object {
      if (mounted) {
        showFixBanner(
          ScaffoldMessenger.of(context),
          message: 'Booking could not be cancelled. Refresh and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
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
        final tracking = widget.controller.tracking;
        final providerName = tracking?.providerName ?? 'the specialist';
        final otp = tracking?.serviceStartOtp ?? '••••';

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
                  'Match $providerName\'s face and official FixNow lanyard credentials prior to doorway entry.',
                ),
                const SizedBox(height: AppSpacing.md),
                _buildSafetyRule(
                  Icons.pin_rounded,
                  'Do Not Disclose OTP Early',
                  'Only provide your start verification code ($otp) once the technician is physically present at the work site.',
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
            providerName:
                widget.controller.tracking?.providerName ??
                'Verified Specialist',
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

    if (widget.onCallPressed != null) {
      widget.onCallPressed!(context, bookingId);
    }
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
    if (value == null || value.status == 'CANCELLED') {
      return const SizedBox.shrink();
    }

    if (value.status == 'IN_PROGRESS') {
      return FixCard(
        tone: FixCardTone.elevated,
        semanticLabel: 'Service currently in progress',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.live,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Service in progress',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const FixStatusChip(
                  label: 'Work started',
                  icon: Icons.handyman_rounded,
                  tone: FixStatusTone.live,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.live.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: AppColors.live.withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    color: AppColors.live,
                    size: 28,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Technician is working on-site',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your provider has arrived and service is underway. Transit map is no longer active.',
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
            ),
          ],
        ),
      );
    }

    if (value.status == 'COMPLETED') {
      return FixCard(
        tone: FixCardTone.elevated,
        semanticLabel: 'Service completed',
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Completed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'All work finished. You can view your invoice and ratings.',
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
              children: [
                Expanded(
                  child: Container(
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
                        Expanded(
                          child: Text(
                            _statusTitle(value.status),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  value.locationAvailability ==
                                      LocationAvailability.live
                                  ? AppColors.primaryEmerald.withValues(
                                      alpha: 0.15,
                                    )
                                  : AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              value.locationAvailability ==
                                      LocationAvailability.live
                                  ? (value.providerLocation != null
                                        ? 'Live location available'
                                        : 'GPS Active')
                                  : 'Live location unavailable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    value.locationAvailability ==
                                        LocationAvailability.live
                                    ? AppColors.primaryEmerald
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed,
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: const Icon(
                            Icons.timer_rounded,
                            color: AppColors.onPrimaryFixed,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'ESTIMATED ARRIVAL',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Expanded(
                                    child: Text(
                                      value.estimatedMinutes == null
                                          ? 'Unavailable'
                                          : '${value.estimatedMinutes} mins',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (value.route != null) ...[
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '(${(value.route!.distanceMeters / 1000).toStringAsFixed(1)} km away)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Traffic Flow',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Clear Road',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _statusTitle(String value) => switch (value.toUpperCase()) {
    'EN_ROUTE' => 'Provider is on the way',
    'IN_PROGRESS' => 'Service in progress',
    'COMPLETED' => 'Service completed',
    'CANCELLED' => 'Booking cancelled',
    _ => 'Live Tracking',
  };
}
