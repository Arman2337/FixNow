import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:flutter/material.dart';

/// Status copy for the active-booking island. The island always says what is
/// happening in plain language — never a raw backend status token.
String fixActiveBookingStatusLabel(String status) => switch (status) {
  'REQUESTED' => 'Finding a pro nearby',
  'ASSIGNED' => 'Pro assigned',
  'EN_ROUTE' => 'On the way to you',
  'IN_PROGRESS' => 'Work in progress',
  'COMPLETED' => 'Completed',
  'CANCELLED' => 'Cancelled',
  _ => 'Booking update',
};

/// The first initial of [name], or a neutral glyph fallback.
String fixActiveBookingInitial(String? name) {
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? '•' : trimmed[0].toUpperCase();
}

/// A persistent pill that keeps the customer's live booking visible on every
/// tab of the shell. It answers the one question that matters while help is on
/// the way — "is it still coming, and when?" — without making the customer
/// open the tracking screen to find out.
///
/// Presentational: pass the resolved strings in and wire the callback. Motion
/// follows [AppMotion.container] and is skipped under
/// `MediaQuery.disableAnimations`.
class FixActiveBookingIsland extends StatefulWidget {
  const FixActiveBookingIsland({
    required this.serviceLabel,
    required this.statusLabel,
    this.etaText,
    this.initial,
    this.onTap,
    super.key,
  });

  /// Service the booking is for, e.g. "Plumbing — Tap Repair".
  final String serviceLabel;

  /// Plain-language status, e.g. "On the way to you".
  final String statusLabel;

  /// Optional arrival phrase, e.g. "6 min".
  final String? etaText;

  /// Provider initial shown in the avatar. Falls back to a neutral dot.
  final String? initial;

  final VoidCallback? onTap;

  @override
  State<FixActiveBookingIsland> createState() => _FixActiveBookingIslandState();
}

class _FixActiveBookingIslandState extends State<FixActiveBookingIsland>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.container);
    _rise = CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduce) {
      _controller.value = 1.0;
    } else if (!_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semanticLabel = StringBuffer('Active booking: ${widget.serviceLabel}');
    semanticLabel.write(', ${widget.statusLabel}');
    if (widget.etaText != null) semanticLabel.write(', arriving in ${widget.etaText}');

    final island = Semantics(
      button: widget.onTap != null,
      label: semanticLabel.toString(),
      child: Material(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryEmerald],
                    ),
                  ),
                  child: Text(
                    fixActiveBookingInitial(widget.initial),
                    style: FixNowTypography.labelLarge.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.serviceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FixNowTypography.labelMedium.copyWith(
                          color: AppColors.textOnDarkPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FixNowTypography.caption.copyWith(
                          color: AppColors.textOnDarkSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.etaText != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.etaText!,
                    style: FixNowTypography.labelLarge.copyWith(
                      color: AppColors.primaryFixed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (widget.onTap != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textOnDarkMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return SlideTransition(
      position:
          Tween(
            begin: const Offset(0, 0.6),
            end: Offset.zero,
          ).animate(_rise),
      child: FadeTransition(opacity: _rise, child: island),
    );
  }
}
