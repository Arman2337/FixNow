import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:flutter/material.dart';

/// Formats a review count or general count into a compact string:
/// 980 → "980", 2300 → "2.3k", 3100 → "3.1k".
String formatReviewCount(int value) {
  if (value < 1000) return value.toString();
  final thousands = value / 1000.0;
  final oneDp = thousands.toStringAsFixed(1);
  final trimmed = oneDp.endsWith('.0')
      ? oneDp.substring(0, oneDp.length - 2)
      : oneDp;
  return '${trimmed}k';
}

/// Formats a rating with its review count into a compact string:
/// e.g. "4.8 ★ (2.3k)"
String formatRatingWithReviews(double rating, int reviewCount) {
  final countStr = formatReviewCount(reviewCount);
  return '${rating.toStringAsFixed(1)} ★ ($countStr)';
}

/// A standard rating display with star icon, rating number, and optional review count.
class FixRatingBadge extends StatelessWidget {
  const FixRatingBadge({
    required this.rating,
    this.reviewCount,
    this.starSize = 14.0,
    this.fontSize = 12.0,
    this.textColor,
    this.reviewColor,
    this.starColor = AppColors.accentGold,
    super.key,
  });

  final double rating;
  final int? reviewCount;
  final double starSize;
  final double fontSize;
  final Color? textColor;
  final Color? reviewColor;
  final Color starColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: starSize, color: starColor),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: textColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
        if (reviewCount != null && reviewCount! > 0) ...[
          const SizedBox(width: 4),
          Text(
            '(${formatReviewCount(reviewCount!)})',
            style: TextStyle(
              color: reviewColor ?? AppColors.textSecondary,
              fontSize: fontSize,
            ),
          ),
        ],
      ],
    );
  }
}
