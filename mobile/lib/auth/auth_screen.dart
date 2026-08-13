import 'package:fixnow_mobile/auth/auth_controller.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_shadows.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.controller, super.key});
  final AuthController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (_register) {
      await widget.controller.register(
        email: _email.text,
        password: _password.text,
      );
    } else {
      await widget.controller.login(
        email: _email.text,
        password: _password.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final loading = widget.controller.status == AuthStatus.loading;
      return Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth >= 600
                    ? AppSpacing.xxl
                    : AppSpacing.pagePadding,
                vertical: constraints.maxWidth >= 600
                    ? AppSpacing.xxxl
                    : AppSpacing.xxl,
              ),
              child: FixPageFrame(
                maxWidth: 480,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    constraints.maxWidth >= 600
                        ? AppSpacing.xxl
                        : AppSpacing.lg,
                  ),
                  decoration: constraints.maxWidth >= 600
                      ? const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.large == 20
                              ? BorderRadius.all(Radius.circular(20))
                              : BorderRadius.zero,
                          border: Border.fromBorderSide(
                            BorderSide(color: AppColors.border),
                          ),
                          boxShadow: AppShadows.floating,
                        )
                      : null,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FixBrandMark(),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          _register ? 'GET STARTED' : 'MEMBER ACCESS',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _register ? 'Create your account' : 'Welcome back',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _register
                              ? 'Book trusted local help and follow every update.'
                              : 'Sign in to request and track trusted help.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        TextFormField(
                          controller: _email,
                          enabled: !loading,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (value) =>
                              RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Enter a valid email address.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _password,
                          enabled: !loading,
                          obscureText: _obscure,
                          autofillHints: _register
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText: _register
                                ? 'Use at least 12 characters.'
                                : null,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => (value?.length ?? 0) < 12
                              ? 'Password must be at least 12 characters.'
                              : null,
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
                          label: _register ? 'Create account' : 'Sign in',
                          onPressed: _submit,
                          isLoading: loading,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FixButton(
                          label: _register
                              ? 'Already have an account? Sign in'
                              : 'New to FixNow? Create account',
                          variant: FixButtonVariant.tertiary,
                          onPressed: loading
                              ? null
                              : () => setState(() => _register = !_register),
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
