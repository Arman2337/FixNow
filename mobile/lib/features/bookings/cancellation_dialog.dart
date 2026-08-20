import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:flutter/material.dart';

Future<String?> showCancellationDialog(BuildContext context) async {
  final reason = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel booking?'),
      content: TextField(
        controller: reason,
        style: const TextStyle(color: AppColors.inputText),
        cursorColor: AppColors.primary,
        autofocus: true,
        maxLines: 3,
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: 'Reason',
          hintText: 'Tell us why you need to cancel.',
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
  );
  reason.dispose();
  return result;
}
