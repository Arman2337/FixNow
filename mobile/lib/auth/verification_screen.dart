import 'package:fixnow_mobile/auth/auth_controller.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:flutter/material.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({required this.controller, super.key});
  final AuthController controller;
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  @override
  void dispose() {
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FixBrandMark(),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Verify your email',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Enter the six-digit code sent to ${widget.controller.verificationEmail}.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextFormField(
                        controller: _code,
                        enabled: !loading,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        validator: (value) =>
                            RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Enter the six-digit code.',
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
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            widget.controller.verify(_code.text);
                          }
                        },
                        isLoading: loading,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FixButton(
                        label: 'Resend code',
                        onPressed: loading
                            ? null
                            : widget.controller.resendVerification,
                        variant: FixButtonVariant.tertiary,
                      ),
                      FixButton(
                        label: 'Use another account',
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
      );
    },
  );
}
