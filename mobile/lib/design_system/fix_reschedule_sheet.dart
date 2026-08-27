import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_schedule_picker.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_schedule.dart';
import 'package:flutter/material.dart';

/// Modal bottom sheet allowing customers to reschedule an active booking without cancelling.
class FixRescheduleSheet extends StatefulWidget {
  const FixRescheduleSheet({
    super.key,
    required this.booking,
    required this.controller,
  });

  final CustomerBooking booking;
  final BookingController controller;

  static Future<CustomerBooking?> show(
    BuildContext context, {
    required CustomerBooking booking,
    required BookingController controller,
  }) {
    return showModalBottomSheet<CustomerBooking>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FixRescheduleSheet(
        booking: booking,
        controller: controller,
      ),
    );
  }

  @override
  State<FixRescheduleSheet> createState() => _FixRescheduleSheetState();
}

class _FixRescheduleSheetState extends State<FixRescheduleSheet> {
  late BookingSchedule _schedule;
  String _selectedReason = 'Not at home during scheduled time';
  bool _submitting = false;
  String? _error;

  static const List<String> _commonReasons = [
    'Not at home during scheduled time',
    'Sudden work / personal emergency',
    'Prefer morning arrival window',
    'Prefer weekend arrival window',
    'Need more time to prepare work area',
  ];

  @override
  void initState() {
    super.initState();
    final dates = BookingSchedule.getUpcomingDates();
    // Default to tomorrow morning
    final tomorrow = dates.length > 1 ? dates[1] : dates[0];
    _schedule = BookingSchedule(
      mode: ScheduleMode.later,
      date: tomorrow,
      slot: TimeSlot.standardSlots[0],
    );
  }

  Future<void> _submitReschedule() async {
    final targetDate = _schedule.targetScheduledAt;
    if (targetDate == null) {
      setState(() => _error = 'Please select a valid scheduled date and arrival slot.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final updated = await widget.controller.reschedule(
        booking: widget.booking,
        newScheduledAt: targetDate,
        reason: _selectedReason,
      );
      if (mounted) {
        Navigator.of(context).pop(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Booking rescheduled to ${_schedule.formattedSummary}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Unable to reschedule booking. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.event_repeat_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Text(
                        'Reschedule Service',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              const Text(
                'Keep your current booking and assigned provider. Choose a new date and arrival window that works best for you.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),

              // Embedded Schedule Picker Card
              FixSchedulePickerCard(
                initialSchedule: _schedule,
                onScheduleChanged: (newSched) {
                  setState(() {
                    _schedule = newSched;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Reason Selector
              FixCard(
                tone: FixCardTone.elevated,
                semanticLabel: 'Reason for rescheduling',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reason for Rescheduling',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedReason,
                      dropdownColor: AppColors.surfaceElevated,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: _commonReasons
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedReason = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (_error case final msg?) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          msg,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // CTA Buttons
              FixButton(
                label: _submitting ? 'Updating schedule...' : 'Confirm New Arrival Time',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _submitting ? null : _submitReschedule,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Keep Current Arrival Time', style: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
