import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:flutter/material.dart';

/// Plain-language age of a completed booking, used as the row's supporting
/// copy. Never a raw date — "Completed 12 days ago" beats "12 Sep".
String fixRebookAgeLabel(DateTime createdAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final days = DateTime(
    reference.year,
    reference.month,
    reference.day,
  ).difference(DateTime(createdAt.year, createdAt.month, createdAt.day)).inDays;
  if (days <= 0) return 'Completed today';
  if (days == 1) return 'Completed yesterday';
  if (days < 7) return 'Completed $days days ago';
  if (days < 14) return 'Completed last week';
  if (days < 60) return 'Completed ${days ~/ 7} weeks ago';
  return 'Completed ${days ~/ 30} months ago';
}

/// One-tap "book again" row for Home.
///
/// A repeat service is the most likely next action for a returning customer,
/// so the last completed bookings sit one tap from Home instead of one tap
/// from the Bookings tab. Empty or unconfigured by design: no bookings, or no
/// callback supplied, and the row renders nothing rather than a placeholder.
class FixRebookRow extends StatelessWidget {
  const FixRebookRow({
    required this.bookings,
    required this.categoryName,
    required this.onBookAgain,
    super.key,
  });

  /// Completed bookings to offer, most recent first. Only completed entries
  /// are rendered; anything else is filtered out here so callers can pass the
  /// raw list.
  final List<CustomerBooking> bookings;

  /// Resolves a category id to its display name.
  final String Function(String categoryId) categoryName;

  final void Function(CustomerBooking booking) onBookAgain;

  static const int _maxItems = 3;

  @override
  Widget build(BuildContext context) {
    final completed = bookings
        .where((booking) => booking.status == 'COMPLETED')
        .take(_maxItems)
        .toList();
    if (completed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Book again',
                  style: FixNowTypography.heading3.copyWith(
                    color: AppColors.textOnSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Flexible (not a bare Text) so the supporting copy wraps or
            // clips at large text scale instead of overflowing the row.
            Flexible(
              child: Text(
                'Your recent services, one tap away',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: FixNowTypography.caption.copyWith(
                  color: AppColors.textOnSurfaceMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // A Wrap, not a horizontal ListView: the row lives inside Home's
        // vertical scroll, and a horizontal viewport there would demand an
        // unbounded height. Wrapping also keeps the row correct at any text
        // scale — cards grow taller instead of clipping.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var index = 0; index < completed.length; index += 1)
              FixScaleIn(
                delay: AppMotion.staggerStep * index,
                child: SizedBox(
                  width: 208,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 116),
                    child: FixCard(
                      semanticLabel:
                          'Book again: ${categoryName(completed[index].serviceCategoryId)}',
                      child: _RebookCardBody(
                        booking: completed[index],
                        categoryLabel:
                            categoryName(completed[index].serviceCategoryId),
                        onBookAgain: onBookAgain,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One rebook offer: service, how long ago it was completed, and the CTA.
class _RebookCardBody extends StatelessWidget {
  const _RebookCardBody({
    required this.booking,
    required this.categoryLabel,
    required this.onBookAgain,
  });

  final CustomerBooking booking;
  final String categoryLabel;
  final void Function(CustomerBooking booking) onBookAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                categoryLabel.trim().isEmpty
                    ? '•'
                    : categoryLabel.trim()[0].toUpperCase(),
                style: FixNowTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                categoryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FixNowTypography.labelLarge.copyWith(
                  color: AppColors.textOnSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          fixRebookAgeLabel(booking.createdAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FixNowTypography.caption.copyWith(
            color: AppColors.textOnSurfaceMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FixButton(
          label: 'Book again',
          variant: FixButtonVariant.primary,
          height: 40,
          expand: true,
          onPressed: () => onBookAgain(booking),
        ),
      ],
    );
  }
}
