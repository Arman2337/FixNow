import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:flutter/material.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({required this.controller, super.key});
  final BookingController controller;
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
          Text(
            'Your bookings',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Follow active requests and review completed work.'),
          const SizedBox(height: AppSpacing.xl),
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
                      child: _BookingCard(booking: booking),
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
  const _BookingCard({required this.booking});
  final CustomerBooking booking;
  @override
  Widget build(BuildContext context) {
    final requested = booking.status == 'REQUESTED';
    return FixCard(
      semanticLabel: '${booking.status} booking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  requested ? 'Finding a provider' : _label(booking.status),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FixStatusChip(
                label: _label(booking.status),
                icon: requested
                    ? Icons.search_rounded
                    : Icons.check_circle_outline,
                tone: requested ? FixStatusTone.info : FixStatusTone.neutral,
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
          Text(
            requested
                ? 'Your request is open to eligible verified providers.'
                : 'Created ${_date(booking.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
