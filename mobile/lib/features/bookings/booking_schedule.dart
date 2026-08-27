import 'package:flutter/material.dart';

enum ScheduleMode { now, later }

/// Represents a standardized 3-hour arrival window for service dispatch.
class TimeSlot {
  const TimeSlot({
    required this.id,
    required this.label,
    required this.timeRange,
    required this.startHour,
    required this.icon,
  });

  final String id;
  final String label;
  final String timeRange;
  final int startHour;
  final IconData icon;

  static const List<TimeSlot> standardSlots = [
    TimeSlot(
      id: 'morning',
      label: 'Morning',
      timeRange: '08:00 AM – 11:00 AM',
      startHour: 8,
      icon: Icons.wb_twilight_rounded,
    ),
    TimeSlot(
      id: 'afternoon',
      label: 'Afternoon',
      timeRange: '12:00 PM – 03:00 PM',
      startHour: 12,
      icon: Icons.wb_sunny_rounded,
    ),
    TimeSlot(
      id: 'evening',
      label: 'Evening',
      timeRange: '04:00 PM – 07:00 PM',
      startHour: 16,
      icon: Icons.nights_stay_rounded,
    ),
  ];
}

/// Holds customer scheduling preferences for a service booking.
class BookingSchedule {
  const BookingSchedule({
    this.mode = ScheduleMode.now,
    required this.date,
    required this.slot,
  });

  final ScheduleMode mode;
  final DateTime date;
  final TimeSlot slot;

  bool get isNow => mode == ScheduleMode.now;

  /// Returns the exact target timestamp for backend dispatch, or null if instant/now.
  DateTime? get targetScheduledAt {
    if (isNow) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      slot.startHour,
      0,
    );
  }

  String get formattedSummary {
    if (isNow) {
      return 'Immediate arrival (~15–30 mins)';
    }
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;

    final prefix = isToday
        ? 'Today'
        : isTomorrow
            ? 'Tomorrow'
            : _weekday(date.weekday);

    final dateNum = '${date.day} ${_monthName(date.month)}';
    return '$prefix ($dateNum) • ${slot.timeRange}';
  }

  BookingSchedule copyWith({
    ScheduleMode? mode,
    DateTime? date,
    TimeSlot? slot,
  }) =>
      BookingSchedule(
        mode: mode ?? this.mode,
        date: date ?? this.date,
        slot: slot ?? this.slot,
      );

  /// Generates the next 7 calendar days starting from today.
  static List<DateTime> getUpcomingDates([DateTime? base]) {
    final start = base ?? DateTime.now();
    return List.generate(
      7,
      (i) => DateTime(start.year, start.month, start.day).add(Duration(days: i)),
    );
  }

  static String _weekday(int day) => switch (day) {
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        7 => 'Sun',
        _ => '',
      };

  static String _monthName(int month) => switch (month) {
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
