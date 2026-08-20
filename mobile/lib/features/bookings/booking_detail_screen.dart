import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/cancellation_dialog.dart';
import 'package:flutter/material.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({
    required this.booking,
    this.onCancel,
    this.onReportIssue,
    super.key,
  });
  final CustomerBooking booking;
  final Future<CustomerBooking> Function(String reason)? onCancel;
  final VoidCallback? onReportIssue;

  @override
  Widget build(BuildContext context) {
    final panel = _statusPanel(booking.status);
    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: SafeArea(
        top: false,
        child: FixPageFrame(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 220),
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(panel.icon, color: panel.color, size: 48),
                    const SizedBox(height: AppSpacing.lg),
                    Text(panel.title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      panel.description,
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
              if (onReportIssue != null) ...[
                const SizedBox(height: AppSpacing.md),
                FixButton(
                  label: 'Report Issue',
                  icon: Icons.report_problem_outlined,
                  variant: FixButtonVariant.secondary,
                  onPressed: onReportIssue,
                ),
              ],
              if (onCancel != null &&
                  const {'REQUESTED', 'ASSIGNED'}.contains(booking.status)) ...[
                const SizedBox(height: AppSpacing.md),
                _CancelButton(booking: booking, onCancel: onCancel!),
              ],
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
  static ({IconData icon, Color color, String title, String description})
  _statusPanel(String value) => switch (value) {
    'REQUESTED' => (
      icon: Icons.radar_rounded,
      color: AppColors.primary,
      title: 'Matching in progress',
      description: 'Provider details appear only after an eligible professional accepts.',
    ),
    'ASSIGNED' || 'EN_ROUTE' || 'IN_PROGRESS' => (
      icon: Icons.route_rounded,
      color: AppColors.primary,
      title: 'Live map unavailable',
      description: 'A map will appear when an assigned provider shares an authorized current location.',
    ),
    'COMPLETED' => (
      icon: Icons.check_circle_rounded,
      color: AppColors.success,
      title: 'Service completed',
      description: 'This booking is complete. Thank you for using FixNow.',
    ),
    'CANCELLED' => (
      icon: Icons.cancel_rounded,
      color: AppColors.danger,
      title: 'Booking cancelled',
      description: 'This booking is no longer active.',
    ),
    _ => (
      icon: Icons.info_outline_rounded,
      color: AppColors.primary,
      title: 'Booking update',
      description: 'The latest booking status is shown below.',
    ),
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

class _CancelButton extends StatefulWidget {
  const _CancelButton({required this.booking, required this.onCancel});
  final CustomerBooking booking;
  final Future<CustomerBooking> Function(String reason) onCancel;

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool loading = false;
  String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error case final message?) ...[
        Text(message, style: const TextStyle(color: AppColors.danger)),
        const SizedBox(height: AppSpacing.sm),
      ],
      FixButton(
        label: 'Cancel booking',
        icon: Icons.cancel_outlined,
        variant: FixButtonVariant.destructive,
        isLoading: loading,
        onPressed: () async {
          final reason = await showCancellationDialog(context);
          if (reason == null) return;
          setState(() {
            loading = true;
            error = null;
          });
          try {
            await widget.onCancel(reason);
            if (context.mounted) Navigator.of(context).pop();
          } catch (_) {
            if (mounted) {
              setState(() {
                loading = false;
                error =
                    'The booking could not be cancelled. Refresh and try again.';
              });
            }
          }
        },
      ),
    ],
  );
}
