import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/design_system/signature_motion.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/recurring_schedule.dart';
import 'package:flutter/material.dart';

enum _BookingFilter { active, completed, cancelled }

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({
    required this.controller,
    this.onBookingSelected,
    this.onBookAgain,
    this.schedulesController,
    this.onOccurrenceConfirmed,
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => RefreshIndicator(
      onRefresh: widget.controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          const FixPageHeader(
            eyebrow: 'Your activity',
            title: 'Your bookings',
            description: 'Track active requests and review completed work.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (widget.schedulesController != null)
            _SchedulesSection(
              controller: widget.schedulesController!,
              onOccurrenceConfirmed: widget.onOccurrenceConfirmed,
            ),
          if (widget.controller.status == BookingListStatus.ready) ...[
            _BookingFilterBar(
              selected: _filter,
              onSelected: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            _BookingSummary(
              activeCount: widget.controller.bookings
                  .where((booking) => _isActive(booking.status))
                  .length,
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
                  ? [_EmptyBookings(filter: _filter)]
                  : _filteredBookings()
                        .map(
                          (booking) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _BookingCard(
                              booking: booking,
                              onTap: widget.onBookingSelected == null
                                  ? null
                                  : () => widget.onBookingSelected!(booking),
                              onBookAgain:
                                  widget.onBookAgain != null &&
                                      booking.status == 'COMPLETED'
                                  ? () => widget.onBookAgain!(booking)
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
          },
        ],
      ),
    ),
  );

  bool _matchesFilter(String status) => switch (_filter) {
    _BookingFilter.active => _isActive(status),
    _BookingFilter.completed => status == 'COMPLETED',
    _BookingFilter.cancelled => status == 'CANCELLED',
  };

  static bool _isActive(String status) => const {
    'REQUESTED',
    'ASSIGNED',
    'EN_ROUTE',
    'IN_PROGRESS',
  }.contains(status);

  List<CustomerBooking> _filteredBookings() => widget.controller.bookings
      .where((booking) => _matchesFilter(booking.status))
      .toList();
}

class _BookingFilterBar extends StatelessWidget {
  const _BookingFilterBar({required this.selected, required this.onSelected});

  final _BookingFilter selected;
  final ValueChanged<_BookingFilter> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Booking filter',
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final filter in _BookingFilter.values)
          ChoiceChip(
            label: Text(_label(filter)),
            selected: selected == filter,
            onSelected: (_) => onSelected(filter),
            selectedColor: AppColors.primarySoft,
            backgroundColor: AppColors.surfacePrimary,
            side: BorderSide(
              color: selected == filter
                  ? AppColors.primary
                  : AppColors.borderDefault,
            ),
            labelStyle: TextStyle(
              color: selected == filter
                  ? AppColors.primary
                  : AppColors.textOnSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    ),
  );

  static String _label(_BookingFilter value) => switch (value) {
    _BookingFilter.active => 'Active',
    _BookingFilter.completed => 'Completed',
    _BookingFilter.cancelled => 'Cancelled',
  };
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({required this.activeCount});
  final int activeCount;

  @override
  Widget build(BuildContext context) => FixCard(
    tone: FixCardTone.elevated,
    semanticLabel: '$activeCount active bookings',
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
            activeCount == 0
                ? 'No active bookings right now'
                : '$activeCount active ${activeCount == 1 ? 'booking' : 'bookings'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      ],
    ),
  );
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
    final requested = booking.status == 'REQUESTED';
    return Semantics(
      button: onTap != null,
      label: '${booking.status} booking. Open details',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            // FN-064 signature motion: lifecycle read by color temperature
            // (cobalt -> green -> amber -> gold), 340ms ease-in-out.
            Positioned(
              left: 0,
              top: 8,
              bottom: 8,
              child: AnimatedContainer(
                duration: AppMotion.container,
                curve: Curves.easeInOut,
                width: 4,
                decoration: BoxDecoration(
                  color: statusTemperatureColor(booking.status),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            FixCard(
          tone: requested ? FixCardTone.elevated : FixCardTone.standard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      requested
                          ? Icons.search_rounded
                          : Icons.receipt_long_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      requested ? 'Finding a provider' : _label(booking.status),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: requested
                            ? AppColors.textOnDarkPrimary
                            : AppColors.textOnLightPrimary,
                      ),
                    ),
                  ),
                  FixStatusChip(
                    label: _label(booking.status),
                    icon: requested
                        ? Icons.search_rounded
                        : Icons.check_circle_outline,
                    tone: requested
                        ? FixStatusTone.info
                        : FixStatusTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                booking.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.iconOnLight,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        requested
                            ? 'Open to eligible verified providers'
                            : 'Created ${_date(booking.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textOnLightSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      'View details',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ],
              if (onBookAgain != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onBookAgain,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Book again'),
                  ),
                ),
              ],
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }

  static String _label(String value) => switch (value) {
    'REQUESTED' => 'Matching',
    'ASSIGNED' => 'Provider assigned',
    'EN_ROUTE' => 'On the way',
    'IN_PROGRESS' => 'In progress',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    _ => value,
  };
  static String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({this.filter});
  final _BookingFilter? filter;
  @override
  Widget build(BuildContext context) => FixCard(
    semanticLabel: 'No bookings yet',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.receipt_long_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          filter == null
              ? 'No bookings yet'
              : 'No ${_filterLabel(filter!)} bookings',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          filter == null
              ? 'Choose a service from Home to request trusted local help.'
              : 'Choose another filter to review a different part of your service history.',
        ),
      ],
    ),
  );

  static String _filterLabel(_BookingFilter value) => switch (value) {
    _BookingFilter.active => 'active',
    _BookingFilter.completed => 'completed',
    _BookingFilter.cancelled => 'cancelled',
  };
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
  const _SchedulesSection({required this.controller, this.onOccurrenceConfirmed});
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
        SchedulesStatus.initial ||
        SchedulesStatus.loading => const Padding(
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.controller,
    this.onConfirmed,
  });
  final RecurringSchedule schedule;
  final SchedulesController controller;
  final VoidCallback? onConfirmed;

  @override
  Widget build(BuildContext context) {
    String? nextVisit;
    final next = schedule.nextOccurrenceAt;
    if (schedule.isActive && next != null) {
      nextVisit =
          '${next.day}/${next.month}/${next.year} '
          '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
    }
    return FixCard(
      tone: schedule.isActive ? FixCardTone.elevated : FixCardTone.standard,
      semanticLabel: 'Repeating ${schedule.cadence == 'WEEKLY' ? 'weekly' : 'monthly'} service',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_repeat_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  schedule.cadence == 'WEEKLY'
                      ? 'Every week'
                      : 'Every month',
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
              (true, final visit?) => 'Next visit: $visit — confirm to book it.',
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
                  onPressed: () async {
                    final bookingId = await controller.confirm(schedule);
                    if (bookingId != null) onConfirmed?.call();
                  },
                ),
              if (schedule.isActive)
                FixButton(
                  label: 'Pause',
                  icon: Icons.pause_circle_outline_rounded,
                  variant: FixButtonVariant.secondary,
                  isLoading: controller.working,
                  onPressed: () =>
                      controller.updateStatus(schedule, 'pause'),
                ),
              if (!schedule.isActive)
                FixButton(
                  label: 'Resume',
                  icon: Icons.play_circle_outline_rounded,
                  variant: FixButtonVariant.secondary,
                  isLoading: controller.working,
                  onPressed: () =>
                      controller.updateStatus(schedule, 'resume'),
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
