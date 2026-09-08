import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/bookings/booking_schedule.dart';
import 'package:flutter/gestures.dart';
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
  late final ScrollController _dateScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _upcomingDates = BookingSchedule.getUpcomingDates();
    _schedule = widget.initialSchedule ?? _computeInitialSchedule();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  BookingSchedule _computeInitialSchedule() {
    final today = _upcomingDates.first;
    final availableTodaySlot = TimeSlot.standardSlots.cast<TimeSlot?>().firstWhere(
      (slot) => !_isSlotPast(today, slot!),
      orElse: () => null,
    );

    if (availableTodaySlot != null) {
      return BookingSchedule(
        mode: ScheduleMode.now,
        date: today,
        slot: availableTodaySlot,
      );
    } else {
      final tomorrow = _upcomingDates.length > 1 ? _upcomingDates[1] : today;
      return BookingSchedule(
        mode: ScheduleMode.now,
        date: tomorrow,
        slot: TimeSlot.standardSlots.first,
      );
    }
  }

  void _updateSchedule(BookingSchedule newSchedule) {
    setState(() => _schedule = newSchedule);
    widget.onScheduleChanged(newSchedule);
  }

  void _selectScheduleLater() {
    var targetSchedule = _schedule.copyWith(mode: ScheduleMode.later);
    final allTodayPast = TimeSlot.standardSlots.every((s) => _isSlotPast(targetSchedule.date, s));
    if (allTodayPast && _upcomingDates.length > 1) {
      final tomorrow = _upcomingDates[1];
      targetSchedule = targetSchedule.copyWith(
        date: tomorrow,
        slot: TimeSlot.standardSlots.first,
      );
    } else if (_isSlotPast(targetSchedule.date, targetSchedule.slot)) {
      final firstAvail = TimeSlot.standardSlots.cast<TimeSlot?>().firstWhere(
        (s) => !_isSlotPast(targetSchedule.date, s!),
        orElse: () => null,
      );
      if (firstAvail != null) {
        targetSchedule = targetSchedule.copyWith(slot: firstAvail);
      }
    }
    _updateSchedule(targetSchedule);
  }

  void _onDateSelected(DateTime date) {
    final index = _upcomingDates.indexWhere(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );
    if (index != -1) {
      _scrollToIndex(index);
    }
    var targetSchedule = _schedule.copyWith(date: date);
    if (_isSlotPast(date, targetSchedule.slot)) {
      final firstAvail = TimeSlot.standardSlots.cast<TimeSlot?>().firstWhere(
        (s) => !_isSlotPast(date, s!),
        orElse: () => null,
      );
      if (firstAvail != null) {
        targetSchedule = targetSchedule.copyWith(slot: firstAvail);
      }
    }
    _updateSchedule(targetSchedule);
  }

  void _scrollToIndex(int index) {
    if (!_dateScrollController.hasClients) return;
    const itemWidth = 76.0 + AppSpacing.xs;
    final targetOffset = (index * itemWidth - 60).clamp(
      0.0,
      _dateScrollController.position.maxScrollExtent,
    );
    _dateScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
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
                      color: AppColors.textPrimary,
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
              color: AppColors.backgroundPrimary,
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
                    onTap: _selectScheduleLater,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Date',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (!_dateScrollController.hasClients) return;
                        _dateScrollController.animateTo(
                          (_dateScrollController.offset - 160).clamp(
                            0.0,
                            _dateScrollController.position.maxScrollExtent,
                          ),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (!_dateScrollController.hasClients) return;
                        _dateScrollController.animateTo(
                          (_dateScrollController.offset + 160).clamp(
                            0.0,
                            _dateScrollController.position.maxScrollExtent,
                          ),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 70,
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
                    if (!_dateScrollController.hasClients) return;
                    final target = (_dateScrollController.offset + event.scrollDelta.dy)
                        .clamp(0.0, _dateScrollController.position.maxScrollExtent);
                    _dateScrollController.jumpTo(target);
                  }
                },
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: ListView.separated(
                    controller: _dateScrollController,
                    physics: const BouncingScrollPhysics(),
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
                        onTap: () => _onDateSelected(date),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 76,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.backgroundPrimary,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${date.day} ${_shortMonth(date.month)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
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
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Time Window Slots
            Text(
              'Select Preferred Arrival Window',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final slot in TimeSlot.standardSlots) ...[
              _buildSlotTile(slot),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],

          const SizedBox(height: AppSpacing.sm),
          // Active Schedule Indicator
          Builder(
            builder: (context) {
              final allSlotsPast = !_schedule.isNow &&
                  TimeSlot.standardSlots.every((s) => _isSlotPast(_schedule.date, s));
              if (allSlotsPast) {
                return const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'All arrival windows for this date have passed. Please select a later date.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Row(
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlotTile(TimeSlot slot) {
    final isPast = _isSlotPast(_schedule.date, slot);
    final isSelected = _schedule.slot.id == slot.id && !isPast;

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
                  : AppColors.backgroundPrimary,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slot.timeRange,
                        style: TextStyle(
                          color: isPast
                              ? Colors.white24
                              : isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (isPast)
                        const Text(
                          'Passed',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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
          border: isSelected ? Border.all(color: Colors.white24, width: 1) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
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
              color: isSelected ? AppColors.accentGold : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
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
