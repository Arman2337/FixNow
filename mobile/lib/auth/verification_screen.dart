import 'dart:async';

import 'package:fixnow_mobile/auth/auth_controller.dart';
import 'package:fixnow_mobile/auth/local_auth_config.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
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
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: FixPageFrame(
                maxWidth: 460,
                child: FixCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FixBrandMark(),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Verify your email',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(color: AppColors.textOnSurface),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Enter the six-digit code sent to ${widget.controller.verificationEmail}.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.textOnSurfaceSecondary,
                              ),
                        ),
                        if (widget.localOtpBypassEnabled) ...[
                          const SizedBox(height: AppSpacing.md),
                          Semantics(
                            label: 'Local testing verification code 000000',
                            child: const Text(
                              'Local testing: use 000000.',
                              style: TextStyle(
                                color: AppColors.textOnSurfaceSecondary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Verification code',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.textOnSurface),
                        ),
                        const SizedBox(height: AppSpacing.sm),
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
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 10,
                            ),
                            decoration: const InputDecoration(
                              hintText: '000000',
                              counterText: '',
                            ),
                            validator: (value) =>
                                RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Enter the six-digit code.',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${_code.text.length}/6 digits entered',
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textOnSurfaceSecondary,
                              ),
                        ),
                        if (widget.controller.errorMessage
                            case final message?) ...[
                          const SizedBox(height: AppSpacing.md),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        FixButton(
                          label: 'Verify account',
                          icon: Icons.verified_user_outlined,
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              widget.controller.verify(_code.text);
                            }
                          },
                          isLoading: loading,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FixButton(
                          label: _secondsUntilResend > 0
                              ? 'Resend code in 00:${_secondsUntilResend.toString().padLeft(2, '0')}'
                              : 'Resend code',
                          icon: Icons.refresh_rounded,
                          onPressed: loading || _secondsUntilResend > 0
                              ? null
                              : _resendCode,
                          variant: FixButtonVariant.tertiary,
                        ),
                        FixButton(
                          label: 'Use another account',
                          icon: Icons.person_outline_rounded,
                          onPressed: loading ? null : widget.controller.logout,
                          variant: FixButtonVariant.tertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
