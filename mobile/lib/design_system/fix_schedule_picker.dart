import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/bookings/booking_schedule.dart';
import 'package:flutter/material.dart';

/// Card component allowing customers to toggle between immediate ("Book for Now")
/// and scheduled ("Schedule for Later") arrivals with 7-day horizontal strip and 3-hour time slots.
class FixSchedulePickerCard extends StatefulWidget {
  const FixSchedulePickerCard({
    super.key,
    this.initialSchedule,
    required this.onScheduleChanged,
  });

  final BookingSchedule? initialSchedule;
  final ValueChanged<BookingSchedule> onScheduleChanged;

  @override
  State<FixSchedulePickerCard> createState() => _FixSchedulePickerCardState();
}

class _FixSchedulePickerCardState extends State<FixSchedulePickerCard> {
  late BookingSchedule _schedule;
  late final List<DateTime> _upcomingDates;

  @override
  void initState() {
    super.initState();
    _upcomingDates = BookingSchedule.getUpcomingDates();
    _schedule = widget.initialSchedule ??
        BookingSchedule(
          mode: ScheduleMode.now,
          date: _upcomingDates.first,
          slot: TimeSlot.standardSlots[1], // default afternoon
        );
  }

  void _updateSchedule(BookingSchedule newSchedule) {
    setState(() => _schedule = newSchedule);
    widget.onScheduleChanged(newSchedule);
  }

  bool _isSlotPast(DateTime date, TimeSlot slot) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    if (!isToday) return false;
    return now.hour >= (slot.startHour + 3);
  }

  @override
  Widget build(BuildContext context) {
    return FixCard(
      semanticLabel: 'Schedule service time',
      tone: FixCardTone.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Arrival Schedule',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textOnSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Toggle Mode Segmented Control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeTab(
                    label: 'Book for Now',
                    icon: Icons.bolt_rounded,
                    isSelected: _schedule.isNow,
                    onTap: () {
                      _updateSchedule(_schedule.copyWith(mode: ScheduleMode.now));
                    },
                  ),
                ),
                Expanded(
                  child: _ModeTab(
                    label: 'Schedule for Later',
                    icon: Icons.calendar_month_rounded,
                    isSelected: !_schedule.isNow,
                    onTap: () {
                      _updateSchedule(_schedule.copyWith(mode: ScheduleMode.later));
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (_schedule.isNow) ...[
            // Now summary
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.flash_on_rounded, color: AppColors.accentGold, size: 18),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Immediate dispatch — nearest verified technician arrives within ~15–30 mins.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Date Selector Strip
            const Text(
              'Select Date',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _upcomingDates.length,
                separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final date = _upcomingDates[index];
                  final isSelected = date.year == _schedule.date.year &&
                      date.month == _schedule.date.month &&
                      date.day == _schedule.date.day;

                  final now = DateTime.now();
                  final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                  final tomorrow = now.add(const Duration(days: 1));
                  final isTomorrow = date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;

                  final dayLabel = isToday
                      ? 'Today'
                      : isTomorrow
                          ? 'Tomorrow'
                          : BookingSchedule.getUpcomingDates()[index].weekday == 7
                              ? 'Sun'
                              : _scheduleDay(date.weekday);

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      _updateSchedule(_schedule.copyWith(date: date));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.white12,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayLabel,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day} ${_shortMonth(date.month)}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Time Window Slots
            const Text(
              'Select Preferred Arrival Window',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final slot in TimeSlot.standardSlots) ...[
              _buildSlotTile(slot),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],

          const SizedBox(height: AppSpacing.sm),
          // Active Schedule Indicator
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _schedule.formattedSummary,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlotTile(TimeSlot slot) {
    final isSelected = _schedule.slot.id == slot.id;
    final isPast = _isSlotPast(_schedule.date, slot);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: isPast
          ? null
          : () {
              _updateSchedule(_schedule.copyWith(slot: slot));
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : isPast
                  ? Colors.white.withValues(alpha: 0.02)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isPast
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              slot.icon,
              size: 18,
              color: isPast
                  ? Colors.white24
                  : isSelected
                      ? AppColors.primary
                      : Colors.white70,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Text(
                    slot.label,
                    style: TextStyle(
                      color: isPast
                          ? Colors.white24
                          : isSelected
                              ? AppColors.primary
                              : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      isPast ? 'Slot passed' : slot.timeRange,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPast
                            ? Colors.white24
                            : isSelected
                                ? AppColors.primary
                                : Colors.white60,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: isPast
                  ? Colors.white10
                  : isSelected
                      ? AppColors.primary
                      : Colors.white30,
            ),
          ],
        ),
      ),
    );
  }

  static String _scheduleDay(int weekday) => switch (weekday) {
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        _ => 'Sun',
      };

  static String _shortMonth(int month) => switch (month) {
        1 => 'Jan',
        2 => 'Feb',
        3 => 'Mar',
        4 => 'Apr',
        5 => 'May',
        6 => 'Jun',
        7 => 'Jul',
        8 => 'Aug',
        9 => 'Sep',
        10 => 'Oct',
        11 => 'Nov',
        12 => 'Dec',
        _ => '',
      };
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.accentGold : Colors.white60,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
