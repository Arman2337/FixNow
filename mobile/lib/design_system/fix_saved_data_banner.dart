import 'package:fixnow_mobile/data/last_good_cache.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:flutter/material.dart';

/// The "updated X ago" stamp, e.g. `Updated 12m ago`.
String fixSavedDataAgeText(DateTime savedAt, {DateTime? now}) =>
    'Updated ${offlineSnapshotAgeLabel(savedAt, now: now)}';

/// The persistent strip that says the page is showing the last thing that was
/// true, and when.
///
/// DESIGN.md §28 requires the last verified booking state to stay visible when
/// the connection drops, marked with its update time and flagged as possibly
/// out of date. This is that marking. It is deliberately worded as a fact about
/// *this screen's* data rather than as a global connectivity claim — the app
/// may well have a working socket while this particular read failed.
///
/// Presentational and stateless: pass the save time in and wire the retry. A
/// null [savedAt] renders nothing at all, so a screen can leave the widget in
/// the tree unconditionally.
class FixSavedDataBanner extends StatelessWidget {
  const FixSavedDataBanner({
    this.savedAt,
    this.onRetry,
    this.now,
    super.key,
  });

  /// When the shown data was last confirmed by the server. Null renders nothing.
  final DateTime? savedAt;

  /// Re-attempts the live read. Null hides the action rather than offering a
  /// button that does nothing.
  final VoidCallback? onRetry;

  /// Injectable clock reference, so the stamp is testable.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final savedAt = this.savedAt;
    if (savedAt == null) return const SizedBox.shrink();

    final age = fixSavedDataAgeText(savedAt, now: now);

    return Semantics(
      // A live region: the stamp appears without the user navigating, and a
      // screen-reader user must be told the data they are reading is cached.
      liveRegion: true,
      label:
          'Showing saved data. $age. This may be out of date until you reconnect.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              // Flexible + maxLines so a 200% text scale wraps instead of
              // overflowing a fixed-height row (DESIGN.md §31).
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Showing saved data',
                    style: FixNowTypography.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$age · may be out of date',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FixNowTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(48, 44),
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}