import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:flutter/material.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({required this.booking, super.key});
  final CustomerBooking booking;

  @override
  Widget build(BuildContext context) {
    final active = const {
      'ASSIGNED',
      'EN_ROUTE',
      'IN_PROGRESS',
    }.contains(booking.status);
    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: SafeArea(
        top: false,
        child: FixPageFrame(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              Container(
                height: 220,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? Icons.route_rounded : Icons.radar_rounded,
                      color: AppColors.primary,
                      size: 48,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      active ? 'Live map unavailable' : 'Matching in progress',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      active
                          ? 'A map will appear when an assigned provider shares an authorized current location.'
                          : 'Provider details appear only after an eligible professional accepts.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                _title(booking.status),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: FixStatusChip(
                  label: _label(booking.status),
                  icon: _icon(booking.status),
                  tone: _tone(booking.status),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FixCard(
                tone: FixCardTone.elevated,
                semanticLabel: 'Booking request details',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service request',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(booking.description),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    Text(
                      'Booking ID',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SelectableText(booking.id),
                    const SizedBox(height: AppSpacing.md),
                    Text('Requested ${_date(booking.createdAt)}'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const FixCard(
                semanticLabel: 'Booking data availability note',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_rounded, color: AppColors.primary),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Provider identity, ETA, price, call, and chat appear only when authoritative data is available.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _title(String value) => switch (value) {
    'REQUESTED' => 'Finding the right professional',
    'ASSIGNED' => 'Provider assigned',
    'EN_ROUTE' => 'Your provider is on the way',
    'IN_PROGRESS' => 'Service in progress',
    'COMPLETED' => 'Service completed',
    'CANCELLED' => 'Booking cancelled',
    _ => 'Booking update',
  };
  static String _label(String value) => value.replaceAll('_', ' ');
  static IconData _icon(String value) => switch (value) {
    'REQUESTED' => Icons.radar_rounded,
    'ASSIGNED' => Icons.person_pin_circle_rounded,
    'EN_ROUTE' => Icons.navigation_rounded,
    'IN_PROGRESS' => Icons.handyman_rounded,
    'COMPLETED' => Icons.check_circle_rounded,
    'CANCELLED' => Icons.cancel_rounded,
    _ => Icons.info_outline_rounded,
  };
  static FixStatusTone _tone(String value) => switch (value) {
    'COMPLETED' => FixStatusTone.success,
    'CANCELLED' => FixStatusTone.danger,
    'REQUESTED' || 'ASSIGNED' => FixStatusTone.warning,
    _ => FixStatusTone.info,
  };
  static String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
}
