import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';

class FixNotificationBellIcon extends StatefulWidget {
  const FixNotificationBellIcon({
    super.key,
    required this.controller,
    this.onTap,
  });

  final NotificationController controller;
  final VoidCallback? onTap;

  @override
  State<FixNotificationBellIcon> createState() =>
      _FixNotificationBellIconState();
}

class _FixNotificationBellIconState extends State<FixNotificationBellIcon> {
  late NotificationController _controller;
  int _lastCount = 0;
  int _shake = 0;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _lastCount = _controller.unreadCount;
    _controller.addListener(_onChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache here (not initState) — inherited-widget reads aren't allowed
    // before the first dependency pass.
    _reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(FixNotificationBellIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != _controller) {
      _controller.removeListener(_onChanged);
      _controller = widget.controller;
      _lastCount = _controller.unreadCount;
      _controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final count = _controller.unreadCount;
    if (count == _lastCount) return;
    final grew = count > _lastCount;
    _lastCount = count;
    if (!mounted) return;
    // Always rebuild (badge text/icon follow the count); shake only when
    // news arrives, and never under reduce motion.
    setState(() {
      if (grew && !_reduce) _shake += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = _controller.unreadCount;
    final hasUnread = unread > 0;

    final bell = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceElevated,
        border: Border.all(
          color: hasUnread
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.borderDefault,
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            hasUnread
                ? Icons.notifications_active_rounded
                : Icons.notifications_outlined,
            color: hasUnread ? Colors.white : AppColors.textSecondary,
            size: 22,
          ),
          if (hasUnread)
            Positioned(
              top: 6,
              right: 6,
              // Keyed on the count so the pop replays for every new push.
              child: FixScaleIn(
                key: ValueKey(unread),
                from: 0.4,
                child: _badge(unread),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: hasUnread
          ? 'Activity and notifications, $unread unread alerts'
          : 'Activity and notifications',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          // Damped ring on news: amplitude decays over three half-swings, then
          // rests. _shake == 0 keeps the very first build static.
          child: _shake == 0
              ? bell
              : TweenAnimationBuilder<double>(
                  key: ValueKey(_shake),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (context, value, child) => Transform.rotate(
                    angle: math.sin(value * math.pi * 3) * 0.22 * (1 - value),
                    child: child,
                  ),
                  child: bell,
                ),
        ),
      ),
    );
  }

  Widget _badge(int unread) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.emergency,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.surfaceElevated, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: AppColors.emergency.withValues(alpha: 0.5),
          blurRadius: 4,
          spreadRadius: 1,
        ),
      ],
    ),
    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
    child: Center(
      child: Text(
        unread > 9 ? '9+' : '$unread',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    ),
  );
}
