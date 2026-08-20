import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:flutter/material.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({
    required this.controller,
    this.onBookingSelected,
    super.key,
  });
  final BookingController controller;
  final ValueChanged<CustomerBooking>? onBookingSelected;
  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
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
              widget.controller.bookings
                  .map(
                    (booking) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _BookingCard(
                        booking: booking,
                        onTap: widget.onBookingSelected == null
                            ? null
                            : () => widget.onBookingSelected!(booking),
                      ),
                    ),
                  )
                  .toList(),
          },
        ],
      ),
    ),
  );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});
  final CustomerBooking booking;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final requested = booking.status == 'REQUESTED';
    return Semantics(
      button: onTap != null,
      label: '${booking.status} booking. Open details',
      child: GestureDetector(
        onTap: onTap,
        child: FixCard(
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
            ],
          ),
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
  const _EmptyBookings();
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
        Text('No bookings yet', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        const Text('Choose a service from Home to request trusted local help.'),
      ],
    ),
  );
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
