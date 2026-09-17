import 'dart:async';

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
    this.recheckInterval = const Duration(seconds: 60),
  });

  final BookingSchedule? initialSchedule;
  final ValueChanged<BookingSchedule> onScheduleChanged;

  /// How often slot availability is re-evaluated against the wall clock.
  /// Pass null to disable the ticker (tests that use [pumpAndSettle]).
  final Duration? recheckInterval;

  @override
  State<FixSchedulePickerCard> createState() => _FixSchedulePickerCardState();
}

class _FixSchedulePickerCardState extends State<FixSchedulePickerCard> {
  late BookingSchedule _schedule;
  late final List<DateTime> _upcomingDates;
  late final ScrollController _dateScrollController = ScrollController();
  Timer? _recheckTimer;

  @override
  void initState() {
    super.initState();
    _upcomingDates = BookingSchedule.getUpcomingDates();
    _schedule = widget.initialSchedule ?? _computeInitialSchedule();
    final interval = widget.recheckInterval;
    if (interval != null) {
      _recheckTimer = Timer.periodic(interval, (_) => _onRecheckTick());
    }
  }

  @override
  void dispose() {
    _recheckTimer?.cancel();
    _dateScrollController.dispose();
    super.dispose();
  }

  /// Keeps the card honest when it sits open across a slot boundary or
  /// midnight: refresh the date strip, then move the selection off any
  /// now-elapsed slot so a stale window can't be booked. Promotion routes
  /// through [_updateSchedule] so the parent's submitted schedule follows.
  void _onRecheckTick() {
    if (!mounted) return;
    final today = DateTime.now();
    final first = _upcomingDates.first;
    final dayRolledOver = first.year != today.year ||
        first.month != today.month ||
        first.day != today.day;
    if (dayRolledOver) {
      setState(() {
        _upcomingDates.clear();
        _upcomingDates.addAll(BookingSchedule.getUpcomingDates());
      });
    }
    if (BookingSchedule.isSlotPast(_schedule.date, _schedule.slot)) {
      _updateSchedule(_promotePastSchedule(_schedule));
    }
  }

  /// Returns [schedule] moved to the first selectable slot on its date — or,
  /// if the whole day has elapsed, to the first slot of the next day.
  BookingSchedule _promotePastSchedule(BookingSchedule schedule) {
    final available = TimeSlot.standardSlots
        .where((s) => !_isSlotPast(schedule.date, s))
        .toList();
    if (available.isNotEmpty) {
      return schedule.copyWith(slot: available.first);
    }
    final laterDays = _upcomingDates.where((d) => d.isAfter(schedule.date)).toList();
    if (laterDays.isNotEmpty) {
      return schedule.copyWith(
        date: laterDays.first,
        slot: TimeSlot.standardSlots.first,
      );
    }
    return schedule;
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
    if (BookingSchedule.isSlotPast(targetSchedule.date, targetSchedule.slot)) {
      targetSchedule = _promotePastSchedule(targetSchedule);
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
    if (BookingSchedule.isSlotPast(date, targetSchedule.slot)) {
      targetSchedule = _promotePastSchedule(targetSchedule);
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

  bool _isSlotPast(DateTime date, TimeSlot slot) =>
      BookingSchedule.isSlotPast(date, slot);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Execution Mode',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
              ),
              const Text(
                'Real-Time SLA',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Toggle Mode Cards
          Row(
            children: [
              Expanded(
                child: _ExecutionModeCard(
                  title: 'Instant SOS',
                  subtitle: '15-Min Arrival',
                  icon: Icons.bolt_rounded,
                  isSelected: _schedule.isNow,
                  subtitleColor: AppColors.primaryFixed,
                  metadata: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryFixed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '5 techs near',
                        style: TextStyle(
                          color: _schedule.isNow ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    _updateSchedule(_schedule.copyWith(mode: ScheduleMode.now));
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ExecutionModeCard(
                  title: 'Schedule',
                  subtitle: 'Pick Slot',
                  icon: Icons.calendar_month_rounded,
                  isSelected: !_schedule.isNow,
                  subtitleColor: AppColors.textSecondary,
                  metadata: Text(
                    'Tomorrow onwards',
                    style: TextStyle(
                      color: !_schedule.isNow ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: _selectScheduleLater,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (_schedule.isNow) ...[
            // Now summary removed since the ExecutionModeCard describes the 15-Min Arrival
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

class _ExecutionModeCard extends StatelessWidget {
  const _ExecutionModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.metadata,
    required this.subtitleColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget metadata;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 112,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? AppColors.primaryFixed : AppColors.textSecondary,
                ),
                if (isSelected)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.onPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  )
                else
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? subtitleColor : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                metadata,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
