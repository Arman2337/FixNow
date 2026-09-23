import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:flutter/material.dart';

Future<String?> showCancellationDialog(BuildContext context) async {
  final reason = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_rounded,
                color: AppColors.danger,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'Cancel booking?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Free Cancellation Active Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Free Cancellation Active',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '100% refund back to original payment method. Zero fee prior to technician arrival.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Quick reasons:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    [
                          'Technician taking too long',
                          'Booked by mistake',
                          'Resolved issue myself',
                          'Found another provider',
                        ]
                        .map(
                          (r) => ActionChip(
                            label: Text(
                              r,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: reason.text == r
                                ? AppColors.primarySoft
                                : AppColors.surfaceContainerLow,
                            side: BorderSide(
                              color: reason.text == r
                                  ? AppColors.primary
                                  : AppColors.outline.withValues(alpha: 0.15),
                            ),
                            onPressed: () {
                              setState(() {
                                reason.text = r;
                              });
                            },
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: reason,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                cursorColor: AppColors.primary,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Tell us why you need to cancel.',
                  labelStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FixButton(
            label: 'Keep booking',
            variant: FixButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          FixButton(
            label: 'Cancel booking',
            variant: FixButtonVariant.destructive,
            onPressed: () {
              final value = reason.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
  reason.dispose();
  return result;
}
