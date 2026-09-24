import 'dart:async';

import 'package:fixnow_mobile/app/app_shell.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/design_system/fix_notification_bell.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/recurring_schedule.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_center_screen.dart';
import 'package:flutter/material.dart';

enum _BookingFilter { all, active, completed, cancelled }

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({
    required this.controller,
    this.onBookingSelected,
    this.onBookAgain,
    this.schedulesController,
    this.onOccurrenceConfirmed,
    this.notificationController,
    this.onOpenProfile,
    super.key,
  });
  final BookingController controller;
  final ValueChanged<CustomerBooking>? onBookingSelected;

  /// FN-112: repeating-service management; null hides the section.
  final SchedulesController? schedulesController;

  /// Called after a schedule occurrence becomes a real booking.
  final VoidCallback? onOccurrenceConfirmed;

  /// Opens a prefilled request for a completed booking; null hides the action.
  final ValueChanged<CustomerBooking>? onBookAgain;

  /// In-app notification controller for bell notifications.
  final NotificationController? notificationController;

  /// Opens customer profile tab/screen.
  final VoidCallback? onOpenProfile;

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  _BookingFilter _filter = _BookingFilter.active;

  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => RefreshIndicator(
      color: AppColors.accentGold,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: widget.controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          // Header
          Row(
            children: [
              const Text(
                'FixNow',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '/',
                  style: TextStyle(
                    color: AppColors.outlineVariant,
                    fontSize: 16,
                  ),
                ),
              ),
              const Text(
                'Bookings',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.notificationController != null)
                    FixNotificationBellIcon(
                      controller: widget.notificationController!,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationCenterScreen(
                              controller: widget.notificationController!,
                              onOpenBooking: (bookingId) {
                                final match = widget.controller.bookings
                                    .where((b) => b.id == bookingId)
                                    .firstOrNull;
                                if (match != null &&
                                    widget.onBookingSelected != null) {
                                  widget.onBookingSelected!(match);
                                }
                              },
                              onOpenInvoice: (_) {},
                            ),
                          ),
                        );
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                      onPressed: () {},
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  Semantics(
                    button: true,
                    label: 'Customer profile',
                    child: Tooltip(
                      message: 'Profile',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (widget.onOpenProfile != null) {
                              widget.onOpenProfile!();
                            } else {
                              final shell = AppShellScope.of(context);
                              if (shell != null) {
                                shell.selectDestination(3, destinationCount: 4);
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceElevated,
                              border: Border.all(
                                color: AppColors.borderDefault,
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (widget.schedulesController != null)
            _SchedulesSection(
              controller: widget.schedulesController!,
              onOccurrenceConfirmed: widget.onOccurrenceConfirmed,
            ),
          if (widget.controller.status == BookingListStatus.ready) ...[
            Builder(
              builder: (context) {
                final all = widget.controller.bookings;
                final counts = <_BookingFilter, int>{
                  _BookingFilter.all: all.length,
                  _BookingFilter.active: all
                      .where((b) => b.statusValue.isActive)
                      .length,
                  _BookingFilter.completed: all
                      .where((b) => b.statusValue.isCompleted)
                      .length,
                  _BookingFilter.cancelled: all
                      .where((b) => b.statusValue.isCancelled)
                      .length,
                };
                return _BookingFilterBar(
                  selected: _filter,
                  counts: counts,
                  onSelected: (value) => setState(() => _filter = value),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _BookingSummary(
              activeCount: widget.controller.bookings
                  .where((b) => b.statusValue.isActive)
                  .length,
              onTap: () {
                final activeBookings = widget.controller.bookings
                    .where((b) => b.statusValue.isActive)
                    .toList();
                if (activeBookings.isNotEmpty) {
                  setState(() => _filter = _BookingFilter.active);
                  if (widget.onBookingSelected != null) {
                    widget.onBookingSelected!(activeBookings.first);
                  }
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          ...switch (widget.controller.status) {
            BookingListStatus.initial || BookingListStatus.loading => const [
              Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading bookings',
                ),
              ),
            ],
            BookingListStatus.empty => [const _EmptyBookings()],
            BookingListStatus.offline => [
              _Failure(
                title: 'You are offline',
                message: 'Reconnect to see your latest bookings.',
                retry: widget.controller.load,
              ),
            ],
            BookingListStatus.error => [
              _Failure(
                title: 'Bookings unavailable',
                message: 'We could not load your bookings.',
                retry: widget.controller.load,
              ),
            ],
            BookingListStatus.ready =>
              _filteredBookings().isEmpty
                  ? [
                      _EmptyBookings(
                        filter: _filter,
                        onReset: () {
                          setState(() {
                            _filter = _BookingFilter.active;
                          });
                        },
                      ),
                    ]
                  : [
                      ..._filteredBookings().map(
                        (booking) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _BookingCard(
                            booking: booking,
                            onTap: widget.onBookingSelected == null
                                ? null
                                : () => widget.onBookingSelected!(booking),
                            onBookAgain:
                                widget.onBookAgain != null &&
                                    booking.statusValue.isCompleted
                                ? () => widget.onBookAgain!(booking)
                                : null,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          bottom: AppSpacing.lg,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              'Schedule New Service',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
          },
        ],
      ),
    ),
  );

  bool _matchesFilter(String status) => switch (_filter) {
    _BookingFilter.all => true,
    _BookingFilter.active => BookingStatusValue.parse(status).isActive,
    _BookingFilter.completed => BookingStatusValue.parse(status).isCompleted,
    _BookingFilter.cancelled => BookingStatusValue.parse(status).isCancelled,
  };

  List<CustomerBooking> _filteredBookings() {
    return widget.controller.bookings.where((booking) {
      return _matchesFilter(booking.status);
    }).toList();
  }
}

class _BookingFilterBar extends StatelessWidget {
  const _BookingFilterBar({
    required this.selected,
    required this.onSelected,
    this.counts = const {},
  });

  final _BookingFilter selected;
  final ValueChanged<_BookingFilter> onSelected;
  final Map<_BookingFilter, int> counts;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Booking filter',
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _BookingFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_label(filter)),
                    if (counts.containsKey(filter)) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${counts[filter]})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected == filter
                              ? AppColors.onPrimary.withValues(alpha: 0.9)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                selected: selected == filter,
                onSelected: (_) => onSelected(filter),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceContainer,
                side: BorderSide(
                  color: selected == filter
                      ? AppColors.primary
                      : AppColors.outline.withValues(alpha: 0.15),
                ),
                labelStyle: TextStyle(
                  color: selected == filter
                      ? AppColors.onPrimary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  static String _label(_BookingFilter value) => switch (value) {
    _BookingFilter.all => 'All',
    _BookingFilter.active => 'Active',
    _BookingFilter.completed => 'Completed',
    _BookingFilter.cancelled => 'Cancelled',
  };
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onTap,
    this.onBookAgain,
  });
  final CustomerBooking booking;
  final VoidCallback? onTap;
  final VoidCallback? onBookAgain;

  @override
  Widget build(BuildContext context) {
    final status = booking.statusValue;

    if (status.isCompleted) {
      return _buildCompletedCard(context);
    } else if (status.isCancelled) {
      return _buildCancelledCard(context);
    } else if (status.isActive) {
      return _buildActiveCard(context);
    }
    return _buildUnknownCard(context);
  }

  Widget _buildActiveCard(BuildContext context) {
    final statusText = booking.statusValue.label.toUpperCase();

    return Semantics(
      button: onTap != null,
      label: '${booking.status} booking. Open details',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Status Micro-Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Radar pulse indicator
                        Container(
                          width: 12,
                          height: 12,
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#FX-${booking.id.length > 5 ? booking.id.substring(0, 5).toUpperCase() : booking.id.toUpperCase()}',
                        style: const TextStyle(
                          color: AppColors.outline,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),

                // Job Title & Subtitle
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.description,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Scheduled for Immediate Response',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                          const Text(
                            'Standard Warranty Included',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Technician Assigned Pod
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Provider Assigned',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Row(
                              children: [
                                Text(
                                  'Professional',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Start PIN Pod
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'START PIN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '••••',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Security Note
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: 15,
                        color: AppColors.outline,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Share PIN only after the professional inspects the setup',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Grid
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: onTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.near_me_rounded, size: 20),
                            label: const Text(
                              'Track Live GPS',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.tonalIcon(
                            onPressed: onTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.secondaryContainer,
                              foregroundColor: AppColors.onSecondaryContainer,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.call_rounded, size: 20),
                            label: const Text(
                              'Call Specialist',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnknownCard(BuildContext context) => Semantics(
    button: onTap != null,
    label: 'Booking status unavailable. Open details',
    child: FixCard(
      onTap: onTap,
      semanticLabel: 'Booking status unavailable',
      child: Row(
        children: [
          const Icon(Icons.help_outline_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status unavailable',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  booking.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildCompletedCard(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: 'Completed booking. Open details',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Status Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Completed Yesterday',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '#FX-${booking.id.length > 5 ? booking.id.substring(0, 5).toUpperCase() : booking.id.toUpperCase()}',
                      style: const TextStyle(
                        color: AppColors.outline,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),

                // Title and Price Row
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.description,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Service Details',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [],
                      ),
                    ],
                  ),
                ),

                // Service Meta & Quick Rating Proof
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: AppColors.outline,
                          ),
                          SizedBox(width: 6),
                          Text(
                            booking.scheduledAt != null
                                ? '${booking.scheduledAt!.day}/${booking.scheduledAt!.month}/${booking.scheduledAt!.year}'
                                : 'Recently',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Buttons Grid
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: onTap,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainerLow,
                              side: BorderSide.none,
                              foregroundColor: AppColors.textPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.receipt_long_rounded,
                              size: 18,
                              color: AppColors.outline,
                            ),
                            label: const Text(
                              'View Tax Invoice',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (onBookAgain != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: FilledButton.tonalIcon(
                              onPressed: onBookAgain,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.surfaceContainerHigh,
                                foregroundColor: AppColors.textPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              label: const Text(
                                'Book again',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelledCard(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: 'Cancelled booking. Open details',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Status Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cancel_rounded,
                            size: 14,
                            color: AppColors.danger,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Cancelled',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '#FX-${booking.id.length > 5 ? booking.id.substring(0, 5).toUpperCase() : booking.id.toUpperCase()}',
                      style: const TextStyle(
                        color: AppColors.outline,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),

                // Title and Refund Row
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.description,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Cancelled by customer',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [],
                      ),
                    ],
                  ),
                ),

                // Refund Policy Disclaimer
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.outline,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Refund terms applied',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.4,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'As per FixNow fair cancellation terms, your booking advance was fully reversed.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.outline,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Help Button
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onTap,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Text(
                        'Need Help With This Job?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      label: const Icon(Icons.chevron_right_rounded, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({this.filter, this.onReset});
  final _BookingFilter? filter;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      vertical: 48,
      horizontal: AppSpacing.lg,
    ),
    alignment: Alignment.center,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.search_off_rounded,
            size: 32,
            color: AppColors.outline,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          filter == null || filter == _BookingFilter.all
              ? 'No bookings yet'
              : 'No ${_filterLabel(filter!)} bookings',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          filter == null || filter == _BookingFilter.all
              ? "We couldn't find any service history matching your query or selected filter."
              : 'Choose another filter to review a different part of your service history.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.outline, fontSize: 12),
        ),
        if (onReset != null) ...[
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: onReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHigh,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Reset Filters',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    ),
  );

  static String _filterLabel(_BookingFilter value) => switch (value) {
    _BookingFilter.all => '',
    _BookingFilter.active => 'active',
    _BookingFilter.completed => 'completed',
    _BookingFilter.cancelled => 'cancelled',
  };
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({required this.activeCount, this.onTap});
  final int activeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (activeCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: FixCard(
          tone: FixCardTone.elevated,
          semanticLabel:
              '$activeCount active ${activeCount == 1 ? 'booking' : 'bookings'}',
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(Icons.route_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '$activeCount active ${activeCount == 1 ? 'booking' : 'bookings'}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.title,
    required this.message,
    required this.retry,
  });
  final String title;
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => FixCard(
    semanticLabel: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(message),
        const SizedBox(height: AppSpacing.lg),
        FixButton(
          label: 'Try again',
          onPressed: retry,
          variant: FixButtonVariant.secondary,
        ),
      ],
    ),
  );
}

/// FN-112: repeating services with manage controls. Each upcoming visit is
/// booked only when the customer confirms it.
class _SchedulesSection extends StatefulWidget {
  const _SchedulesSection({
    required this.controller,
    this.onOccurrenceConfirmed,
  });
  final SchedulesController controller;

  /// Called after a confirmed occurrence becomes a real booking.
  final VoidCallback? onOccurrenceConfirmed;

  @override
  State<_SchedulesSection> createState() => _SchedulesSectionState();
}

class _SchedulesSectionState extends State<_SchedulesSection> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return switch (controller.status) {
        SchedulesStatus.initial || SchedulesStatus.loading => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.lg),
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading repeating services',
            ),
          ),
        ),
        SchedulesStatus.empty => const SizedBox.shrink(),
        SchedulesStatus.offline || SchedulesStatus.error => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: FixCard(
            semanticLabel: 'Repeating services unavailable',
            child: Row(
              children: [
                Expanded(child: Text('Repeating services are unavailable.')),
                TextButton(
                  onPressed: controller.working ? null : controller.load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        SchedulesStatus.ready => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Repeating services',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final schedule in controller.schedules)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ScheduleCard(
                  schedule: schedule,
                  controller: controller,
                  onConfirmed: widget.onOccurrenceConfirmed,
                ),
              ),
          ],
        ),
      };
    },
  );
}

class _ScheduleCard extends StatefulWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.controller,
    this.onConfirmed,
  });
  final RecurringSchedule schedule;
  final SchedulesController controller;
  final VoidCallback? onConfirmed;

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  /// True while the confirm button shows its success morph.
  bool _justConfirmed = false;
  Timer? _successReset;

  @override
  void dispose() {
    _successReset?.cancel();
    super.dispose();
  }

  Future<void> _confirm() async {
    final bookingId = await widget.controller.confirm(widget.schedule);
    if (!mounted) return;
    if (bookingId == null) return;
    // Parent side-effects (dispatch notice, list reload) fire immediately;
    // only the in-place success state holds for a beat.
    widget.onConfirmed?.call();
    setState(() => _justConfirmed = true);
    _successReset?.cancel();
    _successReset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _justConfirmed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final controller = widget.controller;
    String? nextVisit;
    final next = schedule.nextOccurrenceAt;
    if (schedule.isActive && next != null) {
      nextVisit =
          '${next.day}/${next.month}/${next.year} '
          '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
    }
    return FixCard(
      tone: schedule.isActive ? FixCardTone.elevated : FixCardTone.standard,
      semanticLabel:
          'Repeating ${schedule.cadence == 'WEEKLY' ? 'weekly' : 'monthly'} service',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_repeat_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  schedule.cadence == 'WEEKLY' ? 'Every week' : 'Every month',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!schedule.isActive)
                FixStatusChip(
                  label: 'Paused',
                  icon: Icons.pause_circle_outline_rounded,
                  tone: FixStatusTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            schedule.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            switch ((schedule.isActive, nextVisit)) {
              (true, final visit?) =>
                'Next visit: $visit — confirm to book it.',
              _ => 'Paused. Resume to see your next visit.',
            },
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (controller.errorMessage case final message?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (schedule.isActive)
                FixButton(
                  label: 'Confirm visit',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: controller.working,
                  success: _justConfirmed,
                  successLabel: 'Visit booked',
                  onPressed: _confirm,
                ),
              if (schedule.isActive)
                FixButton(
                  label: 'Pause',
                  icon: Icons.pause_circle_outline_rounded,
                  variant: FixButtonVariant.secondary,
                  isLoading: controller.working,
                  onPressed: () => controller.updateStatus(schedule, 'pause'),
                ),
              if (!schedule.isActive)
                FixButton(
                  label: 'Resume',
                  icon: Icons.play_circle_outline_rounded,
                  variant: FixButtonVariant.secondary,
                  isLoading: controller.working,
                  onPressed: () => controller.updateStatus(schedule, 'resume'),
                ),
              TextButton(
                onPressed: controller.working
                    ? null
                    : () => controller.updateStatus(schedule, 'cancel'),
                child: const Text('Stop repeating'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
