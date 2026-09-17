import 'dart:async';

import 'package:fixnow_mobile/auth/auth_controller.dart';
import 'package:fixnow_mobile/auth/local_auth_config.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_shadows.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VerificationScreen extends StatefulWidget {
  VerificationScreen({
    required this.controller,
    bool? localOtpBypassEnabled,
    super.key,
  }) : localOtpBypassEnabled =
           localOtpBypassEnabled ?? LocalAuthConfig.otpBypassEnabled;

  final AuthController controller;
  final bool localOtpBypassEnabled;
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  Timer? _resendTimer;
  int _secondsUntilResend = 30;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(_refreshCodeCount);
    _startResendCooldown();
  }

  void _refreshCodeCount() {
    if (mounted) setState(() {});
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _secondsUntilResend = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsUntilResend <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsUntilResend = 0);
        return;
      }
      setState(() => _secondsUntilResend -= 1);
    });
  }

  Future<void> _resendCode() async {
    if (_secondsUntilResend > 0) return;
    await widget.controller.resendVerification();
    if (mounted && widget.controller.errorMessage == null) {
      _startResendCooldown();
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _code.removeListener(_refreshCodeCount);
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final loading = widget.controller.status == AuthStatus.loading;
      final codeText = _code.text;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Use another account',
            onPressed: loading ? null : widget.controller.logout,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FIXNOW ID',
                style: FixNowTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  fontSize: 10,
                ),
              ),
              Text(
                'Otp Verification',
                style: FixNowTypography.title.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: FixPageFrame(
              maxWidth: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Visual Header Anchor / Shield Security Badge
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryFixed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                size: 32,
                                color: AppColors.onPrimaryFixed,
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'SECURITY CHALLENGE',
                          style: FixNowTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verify Your Account',
                          style: FixNowTypography.headlineLg.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Enter code sent to ${widget.controller.verificationEmail ?? "your account"}',
                                style: FixNowTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: loading
                                  ? null
                                  : widget.controller.logout,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.localOtpBypassEnabled) ...[
                    const SizedBox(height: AppSpacing.sm),
                    // Dev Sandbox Bypass Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  size: 16,
                                  color: AppColors.tertiary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Semantics(
                                    label:
                                        'Local testing verification code 000000',
                                    child: const Text(
                                      'Local testing: use 000000.',
                                      style: TextStyle(
                                        color: AppColors.onTertiaryFixed,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              _code.text = '000000';
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.tertiaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Auto-fill',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  // 6-Digit OTP Interactive Boxes Card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDefault),
                      boxShadow: AppShadows.card,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // 6 Interactive Digits Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              final isFilled = index < codeText.length;
                              final isCurrent = index == codeText.length;
                              return Container(
                                width: 44,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isFilled
                                      ? AppColors.surfaceContainerLow
                                      : (isCurrent
                                            ? AppColors.surfaceContainerLowest
                                            : AppColors.surfaceContainer),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppColors.primary
                                        : AppColors.borderDefault,
                                    width: isCurrent ? 2 : 1,
                                  ),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.15,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: isCurrent
                                      ? Container(
                                          width: 2,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                          // Simple blinking effect handled by flutter engine if we add an animation,
                                          // but for static fidelity we just draw the cursor line or a dot.
                                        )
                                      : Text(
                                          isFilled ? codeText[index] : '•',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: isFilled
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary
                                                      .withValues(alpha: 0.4),
                                          ),
                                        ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // Hidden text field for keyboard input
                          Semantics(
                            label: 'Six digit verification code',
                            textField: true,
                            child: TextFormField(
                              controller: _code,
                              enabled: !loading,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              maxLength: 6,
                              textInputAction: TextInputAction.done,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.inputText,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 8,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Enter 6 digits above',
                                counterText: '',
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              validator: (value) =>
                                  RegExp(
                                    r'^\d{6}$',
                                  ).hasMatch(value?.trim() ?? '')
                                  ? null
                                  : 'Enter the six-digit code.',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Listening for incoming secure dispatch SMS...',
                                  overflow: TextOverflow.ellipsis,
                                  style: FixNowTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.controller.errorMessage
                              case final message?) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  message,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Resend Timer & WhatsApp Action Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Resend in',
                                    style: FixNowTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '00:${_secondsUntilResend.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: loading || _secondsUntilResend > 0
                              ? null
                              : _resendCode,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text(
                            'Resend code',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Trust Profile Guarantee Card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'VERIFIED SHIELD GUARD',
                              style: FixNowTypography.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.lock_person_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Encrypted 256-bit',
                                  style: FixNowTypography.labelSmall.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x05000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                                image: const DecorationImage(
                                  image: NetworkImage(
                                    'https://lh3.googleusercontent.com/aida-public/AB6AXuBkmKmBr13p03fGtTEBOV-3rJJ_QzeSXCbKAbO-CxSdB_oIKmryOEfKoNRby_bgARQ1Gp6uNLNj6e6sFOzHl4J4m7-SQ3hGhGKmmFKnlAmgMGNklZpGet-uaU3e-Z4Vz9P8vYHmNOmPwoSFdQPX0Coe7Moifh0UpTizZrMo5w-3enpi63B0ErkL86KIm4ZFSJEEk-d1qwxHTDiv7PUL01921yu5jIeRFmUbL2RFN_QixkVs2N9xppvb',
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FixNow Instant Keying',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Protects account bookings, invoices, and field keys.',
                                    style: FixNowTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x05000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                                image: const DecorationImage(
                                  image: NetworkImage(
                                    'https://lh3.googleusercontent.com/aida-public/AB6AXuAHdqWrYK6v7US1nQe3EoZoaVlUYoKfYAjzrft1Pz8nu4QHWWQIrj7jHS2DEWq7F_OL4_0J6WseaM_KrwoD3gXdvItmqroTOUjzUuHhWlwpYthIkBIBqHp1BrQlqaGd3TOzrbp3aUJytNkisA51JVztGIa9mfu61dCfdLr9fdNiYN2NVMbrH3JVCWZNt4eHSAGQbPpi3n1CqoHYoeE1yU_Uoses8zUwA9M9CgWe5-LgPk7IRUvLhsks',
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Biometric Toggle Switch
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.fingerprint_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Biometric Quick Login',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Enable Face ID / Fingerprint',
                                  style: FixNowTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: _biometricEnabled,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) =>
                              setState(() => _biometricEnabled = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Primary CTA Button
                  FixButton(
                    label: 'Verify account',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.controller.verify(_code.text);
                      }
                    },
                    isLoading: loading,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'By continuing, you confirm instant secure session generation.',
                    textAlign: TextAlign.center,
                    style: FixNowTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
