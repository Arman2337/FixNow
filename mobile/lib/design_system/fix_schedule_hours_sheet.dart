import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:flutter/material.dart';

/// Modal bottom sheet allowing service providers to customize their recurring
/// working days (e.g. Mon–Fri, Mon–Sat, Everyday, or custom days) and working
/// hours (start/end time) rather than being locked into fixed 09:00–17:00 weekday hours.
class FixProviderWorkingHoursSheet extends StatefulWidget {
  const FixProviderWorkingHoursSheet({required this.controller, super.key});

  final ProviderController controller;

  static Future<void> show(
    BuildContext context, {
    required ProviderController controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          FixProviderWorkingHoursSheet(controller: controller),
    );
  }

  @override
  State<FixProviderWorkingHoursSheet> createState() =>
      _FixProviderWorkingHoursSheetState();
}

class _FixProviderWorkingHoursSheetState
    extends State<FixProviderWorkingHoursSheet> {
  // Days of week: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 0=Sun
  late Set<int> _selectedDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rules = widget.controller.availability?.weeklyRules ?? const [];
    if (rules.isNotEmpty) {
      _selectedDays = rules
          .map((r) => (r['dayOfWeek'] as num?)?.toInt())
          .whereType<int>()
          .toSet();
      final intervals = rules.first['intervals'] as List?;
      if (intervals != null && intervals.isNotEmpty) {
        final first = Map<String, Object?>.from(intervals.first as Map);
        final startMin = (first['startMinute'] as num?)?.toInt() ?? 540;
        final endMin = (first['endMinute'] as num?)?.toInt() ?? 1020;
        _startTime = TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60);
        _endTime = TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60);
      } else {
        _startTime = const TimeOfDay(hour: 9, minute: 0);
        _endTime = const TimeOfDay(hour: 17, minute: 0);
      }
    } else {
      _selectedDays = {1, 2, 3, 4, 5};
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 17, minute: 0);
    }
  }

  void _applyDayPreset(Set<int> days) {
    setState(() {
      _selectedDays = Set.from(days);
      _error = null;
    });
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > 1) {
          _selectedDays.remove(day);
        }
      } else {
        _selectedDays.add(day);
      }
      _error = null;
    });
  }

  void _setTimePreset(int startH, int startM, int endH, int endM) {
    setState(() {
      _startTime = TimeOfDay(hour: startH, minute: startM);
      _endTime = TimeOfDay(hour: endH, minute: endM);
      _error = null;
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surfaceElevated,
            onSurface: AppColors.textPrimary,
            surfaceContainerHighest: AppColors.surfaceSecondary,
            onSurfaceVariant: AppColors.textSecondary,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: AppColors.surfaceElevated,
            dialBackgroundColor: AppColors.surfaceSecondary,
            dialTextColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.textPrimary),
            dialHandColor: AppColors.primary,
            hourMinuteColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.surfaceSecondary),
            hourMinuteTextColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.textPrimary),
            dayPeriodColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primarySoft
                    : Colors.transparent),
            dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.textSecondary),
            dayPeriodBorderSide: const BorderSide(color: AppColors.borderDefault),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    if (_selectedDays.isEmpty) {
      setState(() => _error = 'Please select at least one working day.');
      return;
    }
    if (startMinutes >= endMinutes) {
      setState(() => _error = 'Start time must be before end time.');
      return;
    }

    setState(() => _saving = true);
    try {
      final sortedDays = _selectedDays.toList()..sort();
      final weeklyRules = [
        for (final day in sortedDays)
          {
            'dayOfWeek': day,
            'intervals': [
              {'startMinute': startMinutes, 'endMinute': endMinutes},
            ],
          },
      ];
      await widget.controller.updateSchedule(weeklyRules);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not update working schedule. Please try again.';
      });
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    try {
      await widget.controller.updateSchedule(const []);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not clear schedule. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const daysMeta = [
      {'label': 'Mon', 'day': 1},
      {'label': 'Tue', 'day': 2},
      {'label': 'Wed', 'day': 3},
      {'label': 'Thu', 'day': 4},
      {'label': 'Fri', 'day': 5},
      {'label': 'Sat', 'day': 6},
      {'label': 'Sun', 'day': 0},
    ];

    final hasExistingHours =
        widget.controller.availability?.weeklyRules.isNotEmpty ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
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
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text(
                      'Working Schedule',
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
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Set the days and daily hours when you are available to accept incoming jobs.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Working Days Section
            const Text(
              'Working Days',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Presets row
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                _buildPresetChip(
                  label: 'Mon–Fri',
                  isSelected:
                      _selectedDays.length == 5 &&
                      _selectedDays.contains(1) &&
                      _selectedDays.contains(2) &&
                      _selectedDays.contains(3) &&
                      _selectedDays.contains(4) &&
                      _selectedDays.contains(5),
                  onTap: () => _applyDayPreset({1, 2, 3, 4, 5}),
                ),
                _buildPresetChip(
                  label: 'Mon–Sat',
                  isSelected:
                      _selectedDays.length == 6 &&
                      _selectedDays.contains(1) &&
                      _selectedDays.contains(2) &&
                      _selectedDays.contains(3) &&
                      _selectedDays.contains(4) &&
                      _selectedDays.contains(5) &&
                      _selectedDays.contains(6),
                  onTap: () => _applyDayPreset({1, 2, 3, 4, 5, 6}),
                ),
                _buildPresetChip(
                  label: 'Every day (7 days)',
                  isSelected: _selectedDays.length == 7,
                  onTap: () => _applyDayPreset({0, 1, 2, 3, 4, 5, 6}),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Individual Days Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final item in daysMeta)
                  _buildDayTile(
                    label: item['label']! as String,
                    day: item['day']! as int,
                    isSelected: _selectedDays.contains(item['day']! as int),
                    onTap: () => _toggleDay(item['day']! as int),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Working Hours Section
            const Text(
              'Daily Working Hours',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Time Presets Row
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _buildTimePresetChip('08:00 – 17:00', 8, 0, 17, 0),
                _buildTimePresetChip('09:00 – 17:00', 9, 0, 17, 0),
                _buildTimePresetChip('09:00 – 18:00', 9, 0, 18, 0),
                _buildTimePresetChip('10:00 – 19:00', 10, 0, 19, 0),
                _buildTimePresetChip('08:00 – 20:00', 8, 0, 20, 0),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Custom Start & End Time Pickers
            Row(
              children: [
                Expanded(
                  child: _buildTimeInputBox(
                    label: 'Start Time',
                    time: _startTime,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildTimeInputBox(
                    label: 'End Time',
                    time: _endTime,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Save and Clear Actions
            FixPrimaryButton(
              label: 'Save working hours',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _saving,
              onPressed: _save,
            ),
            if (hasExistingHours) ...[
              const SizedBox(height: AppSpacing.sm),
              FixSecondaryButton(
                label: 'Clear recurring hours',
                icon: Icons.delete_outline_rounded,
                onPressed: _saving ? null : _clear,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.backgroundPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(color: isSelected ? AppColors.primary : Colors.white12),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildTimePresetChip(
    String label,
    int startH,
    int startM,
    int endH,
    int endM,
  ) {
    final isSelected =
        _startTime.hour == startH &&
        _startTime.minute == startM &&
        _endTime.hour == endH &&
        _endTime.minute == endM;

    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected
          ? AppColors.primary
          : AppColors.backgroundPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(color: isSelected ? AppColors.primary : Colors.white12),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: () => _setTimePreset(startH, startM, endH, endM),
    );
  }

  Widget _buildDayTile({
    required String label,
    required int day,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white12,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInputBox({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    final hourStr =
        (time.hour == 0
                ? 12
                : time.hour > 12
                ? time.hour - 12
                : time.hour)
            .toString()
            .padLeft(2, '0');
    final minuteStr = time.minute.toString().padLeft(2, '0');
    final periodStr = time.period == DayPeriod.am ? 'AM' : 'PM';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$hourStr:$minuteStr $periodStr',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.access_time_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
