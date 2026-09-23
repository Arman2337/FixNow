import 'package:fixnow_mobile/auth/auth_controller.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.controller,
    required this.role,
    required this.initialRegister,
    required this.onBack,
    super.key,
  });
  final AuthController controller;
  final AccountRole role;
  final bool initialRegister;
  final VoidCallback onBack;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _mobile = TextEditingController();
  final _referral = TextEditingController();
  late bool _register;
  bool _obscure = true;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _register = widget.initialRegister;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.clearError();
    });
    _email.addListener(_onInputChanged);
    _password.addListener(_onInputChanged);
    _fullName.addListener(_onInputChanged);
    _mobile.addListener(_onInputChanged);
    _referral.addListener(_onInputChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _onInputChanged() {
    if (widget.controller.errorMessage != null) {
      widget.controller.clearError();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _email.removeListener(_onInputChanged);
    _password.removeListener(_onInputChanged);
    _fullName.removeListener(_onInputChanged);
    _referral.removeListener(_onInputChanged);
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _mobile.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (_register) {
      await widget.controller.register(
        email: _email.text,
        password: _password.text,
        role: widget.role,
        mobile: _mobile.text.trim().isNotEmpty ? _mobile.text : null,
        fullName: _fullName.text.trim().isNotEmpty ? _fullName.text : null,
      );
    } else {
      await widget.controller.login(
        email: _email.text,
        password: _password.text,
        role: widget.role,
        mobile: _mobile.text.trim().isNotEmpty ? _mobile.text : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final loading = widget.controller.status == AuthStatus.loading;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceContainerLowest.withValues(
            alpha: 0.8,
          ),
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: loading ? null : widget.onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FIXNOW ID',
                  style: FixNowTypography.dataMono.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
                Text(
                  'Phone Login',
                  style: FixNowTypography.headlineMd.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.surfaceContainerHigh,
                child: const Icon(
                  Icons.person,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: FixPageFrame(
              maxWidth: 480,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Subtle Ambient Glow & Trust Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: 0.5 + (_pulseController.value * 0.5),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'DIRECT DISPATCH ACTIVE',
                                overflow: TextOverflow.ellipsis,
                                style: FixNowTypography.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'FixSafe Protected',
                                overflow: TextOverflow.ellipsis,
                                style: FixNowTypography.dataMono.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Segmented Toggle Control
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0A000000), blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: loading
                                ? null
                                : () {
                                    if (_register) {
                                      widget.controller.clearError();
                                      setState(() => _register = false);
                                    }
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_register
                                    ? AppColors.surfaceContainerLowest
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: !_register
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x0D000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.login_rounded,
                                    size: 16,
                                    color: !_register
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Sign In',
                                    style: FixNowTypography.label.copyWith(
                                      color: !_register
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: loading
                                ? null
                                : () {
                                    if (!_register) {
                                      widget.controller.clearError();
                                      setState(() => _register = true);
                                    }
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _register
                                    ? AppColors.surfaceContainerLowest
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _register
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x0D000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add_rounded,
                                    size: 16,
                                    color: _register
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Create Account',
                                    style: FixNowTypography.label.copyWith(
                                      color: _register
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Dynamic Header Area
                  Text(
                    _register ? 'Create FixNow ID' : 'Welcome Back',
                    style: FixNowTypography.headlineLg.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _register
                        ? 'Register your home to track quick repairs, warranties, and emergency dispatches.'
                        : 'Enter your mobile number or email to access your bookings & warranty protection.',
                    style: FixNowTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Main Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (kDebugMode) ...[
                          ElevatedButton.icon(
                            key: const Key('quick_login_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.flash_on,
                              color: Colors.amber,
                              size: 18,
                            ),
                            label: Text(
                              widget.role == AccountRole.customer
                                  ? '⚡ Quick Login (Customer A)'
                                  : '⚡ Quick Login (Provider A)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              setState(() => _register = false);
                              if (widget.role == AccountRole.customer) {
                                _email.text =
                                    'fixnow.acceptance.customer-a@local.test';
                                _password.text =
                                    'FixNow-local-customer-a-2026!';
                              } else {
                                _email.text =
                                    'fixnow.acceptance.provider-a@local.test';
                                _password.text =
                                    'FixNow-local-provider-a-2026!';
                              }
                              _submit();
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Full Name (Register Only)
                        if (_register) ...[
                          const Text(
                            'Full Name',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _fullName,
                            enabled: !loading,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. Rahul Sharma',
                              hintStyle: TextStyle(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceContainerLowest,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) =>
                                _register &&
                                    (value == null || value.trim().isEmpty)
                                ? 'Enter your full name.'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Mobile Field (Mandatory)
                        if (_register) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Mobile Number',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.smartphone_outlined,
                                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                                Container(
                                  height: 24,
                                  width: 1,
                                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                                  margin: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                // +91 Prefix Pill
                                Container(
                                  margin: const EdgeInsets.only(top: 6, bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '+91',
                                        style: FixNowTypography.dataMono.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _mobile,
                                    enabled: !loading,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter your mobile number',
                                      hintStyle: TextStyle(
                                        color: AppColors.textSecondary.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 14,
                                      ),
                                    ),
                                    validator: (value) =>
                                        (value == null || value.trim().isEmpty)
                                            ? 'Enter your mobile number.'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Email Field (Mandatory)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Email Address',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'VERIFIED ID',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _email,
                          enabled: !loading,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'name@mail.com',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLowest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) =>
                              RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Enter a valid email address.',
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Password Field
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Security Password',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (!_register)
                              GestureDetector(
                                onTap: () {},
                                child: Text(
                                  'Forgot Password?',
                                  style: FixNowTypography.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _password,
                          enabled: !loading,
                          obscureText: _obscure,
                          autofillHints: _register
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your secure password',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.5,
                              ),
                              letterSpacing: 0,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLowest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
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
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          validator: (value) => (value?.length ?? 0) < 12
                              ? 'Password must be at least 12 characters.'
                              : null,
                        ),

                        // Referral Field (Register Only)
                        if (_register &&
                            widget.role == AccountRole.customer) ...[
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Referral Code (Optional)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Get ₹150 OFF',
                                style: TextStyle(
                                  color: AppColors.tertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _referral,
                            enabled: !loading,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            style: FixNowTypography.dataMono.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'e.g. FIXSAFE2025',
                              hintStyle: TextStyle(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.local_offer_outlined,
                                size: 20,
                                color: AppColors.tertiary,
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceContainerLowest,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],

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
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),

                        // Primary Emerald CTA
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              shadowColor: AppColors.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _register
                                            ? 'Create Account & Continue'
                                            : 'Sign In to FixNow',
                                        style: FixNowTypography.headlineMd
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              letterSpacing: -0.5,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Social Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.surfaceContainerHigh,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR CONNECT WITH',
                            style: FixNowTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 1.2,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.surfaceContainerHigh,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Social Tray
                  Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          icon: Icons.g_mobiledata_rounded,
                          iconSize: 36,
                          iconColor: Colors.red,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Coming soon',
                      style: FixNowTypography.labelSmall.copyWith(
                        color: AppColors.outline,
                        fontSize: 10,
                      ),
                    ),
                  ),

                  // Trust Badges
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_rounded,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '30-Day FixNow Warranty',
                                  style: FixNowTypography.label.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryFixed.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '₹0 Deductible',
                                style: FixNowTypography.dataMono.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            SizedBox(
                              width: 60,
                              height: 28,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.blueGrey,
                                      child: const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 16,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.brown,
                                      child: const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 32,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.deepOrange,
                                      child: const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: FixNowTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  children: const [
                                    TextSpan(text: 'Joined by '),
                                    TextSpan(
                                      text: '14,200+',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' verified pros ready across your city.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Statutory Legal & ISO Compliance Footnote
                  const SizedBox(height: AppSpacing.lg),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '256-Bit SSL Bank Grade Encryption',
                            style: FixNowTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your data is encrypted under IT Act 2000 & ISO 27001 standards.',
                        textAlign: TextAlign.center,
                        style: FixNowTypography.bodySmall.copyWith(
                          color: AppColors.outline,
                          fontSize: 11,
                        ),
                      ),
                    ],
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

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}
