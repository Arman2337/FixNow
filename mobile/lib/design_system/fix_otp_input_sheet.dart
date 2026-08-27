import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal bottom sheet for technicians to input the customer's 4-digit service start code.
class FixOtpInputSheet extends StatefulWidget {
  const FixOtpInputSheet({super.key});

  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const FixOtpInputSheet(),
      );

  @override
  State<FixOtpInputSheet> createState() => _FixOtpInputSheetState();
}

class _FixOtpInputSheetState extends State<FixOtpInputSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.length != 4 || !RegExp(r'^\d{4}$').hasMatch(code)) {
      setState(() {
        _errorText = 'Please enter all 4 digits.';
      });
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final code = _controller.text;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Service Code',
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.cream,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ask the customer for the 4-digit code',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // 4-Digit Display Boxes
          GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final hasDigit = index < code.length;
                final isCurrent = index == code.length;
                return Container(
                  width: 56,
                  height: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: isCurrent
                          ? AppColors.primary
                          : (hasDigit ? AppColors.accentGold : AppColors.borderStrong),
                      width: isCurrent || hasDigit ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hasDigit ? code[index] : '',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cream,
                    ),
                  ),
                );
              }),
            ),
          ),

          // Hidden real text field for keyboard capture
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 1,
              child: TextField(
                key: const Key('otp_hidden_input'),
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (val) {
                  setState(() {
                    _errorText = '';
                  });
                  if (val.length == 4) {
                    _submit();
                  }
                },
              ),
            ),
          ),

          if (_errorText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: const Row(
              children: [
                Icon(Icons.security_rounded, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Work starts only after the code is verified on the server.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FixButton(
            key: const Key('otp_verify_button'),
            label: 'Verify & Start Service',
            icon: Icons.check_circle_outline_rounded,
            onPressed: code.length == 4 ? _submit : null,
          ),
        ],
      ),
    );
  }
}
