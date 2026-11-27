import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
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
        const FixSectionHeader(
          title: 'Book again',
          subtitle: 'Your recent services, one tap away',
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 360.0;
            final cardWidth = completed.length == 1
                ? maxW
                : (maxW < 252 ? maxW : 216.0);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < completed.length; index += 1) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.sm),
                      FixScaleIn(
                        delay: AppMotion.staggerStep * index,
                        child: SizedBox(
                          width: cardWidth,
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
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// One rebook offer: service, scope summary, completion age, and the CTA.
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
    final description = booking.description.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        if (description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FixNowTypography.bodySmall.copyWith(
              color: AppColors.textOnSurfaceSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          fixRebookAgeLabel(booking.createdAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FixNowTypography.caption.copyWith(
            color: AppColors.textOnSurfaceMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Spacer(),
        FixButton(
          label: 'Book again',
          variant: FixButtonVariant.primary,
          height: 48,
          expand: true,
          onPressed: () => onBookAgain(booking),
        ),
      ],
    );
  }
}
