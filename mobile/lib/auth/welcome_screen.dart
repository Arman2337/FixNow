import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onGetStarted,
    required this.onSignIn,
    super.key,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: FixPageFrame(
            maxWidth: 520,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppSpacing.xl * 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: FixBrandMark(),
                  ),
                  SizedBox(height: constraints.maxHeight < 700 ? 40 : 80),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: AppRadius.cardBorder,
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: const Row(
                      children: [
                        _WelcomeHeroIcon(),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Help that keeps you informed',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: AppSpacing.xs),
                              Text(
                                'Request, match, and track a trusted professional in one place.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Trusted help.\nWhen you need it.',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.cream,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Book reliable local professionals, see clear updates, and stay in control from request to completion.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _buildTrustPill(
                        Icons.verified_user_rounded,
                        'Verified professionals',
                      ),
                      _buildTrustPill(Icons.route_outlined, 'Live job updates'),
                      _buildTrustPill(Icons.shield_outlined, 'Work-start OTP'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  FixButton(label: 'Get started', onPressed: onGetStarted),
                  const SizedBox(height: AppSpacing.sm),
                  FixButton(
                    label: 'Sign in',
                    onPressed: onSignIn,
                    variant: FixButtonVariant.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildTrustPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Icon(icon, size: 13, color: AppColors.accentGold),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textOnLightPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHeroIcon extends StatelessWidget {
  const _WelcomeHeroIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: const Icon(
      Icons.home_repair_service_rounded,
      size: 28,
      color: AppColors.onPrimary,
    ),
  );
}
