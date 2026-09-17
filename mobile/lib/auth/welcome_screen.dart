
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    required this.onContinue,
    super.key,
  });

  /// Called when the user proceeds. [isRegister] is true for the primary CTA,
  /// and false if they tap 'Sign In'.
  final void Function(AccountRole role, bool isRegister) onContinue;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  AccountRole _selected = AccountRole.customer;

  String get _ctaLabel => _selected == AccountRole.customer
      ? 'Continue as Customer'
      : 'Join as Service Partner';

  /// Entrance delay for the block at [slot] on the 60ms stagger clock.
  static Duration _at(int slot) => AppMotion.staggerStep * slot;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: FixPageFrame(
              maxWidth: 520,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.lg * 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── 1. Top Utility Bar: Official Badge + Language Switcher ───
                    FixFadeSlideIn(
                      delay: _at(0),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          bottom: AppSpacing.xs,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    size: 15,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'OFFICIAL ON-DEMAND',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: FixNowTypography.dataMono.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // ─── 2. Brand Identity Header ───
                    FixFadeSlideIn(
                      delay: _at(1),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1A000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.home_repair_service_rounded,
                                  size: 40,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Fix',
                                        style: FixNowTypography.headlineLg.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Now',
                                        style: FixNowTypography.headlineLg.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryFixed,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.bolt_rounded,
                                      size: 13,
                                      color: AppColors.onPrimaryFixed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fast, Verified & Fair Home Services',
                              style: FixNowTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ─── 3. Hero Highlight / Trust Micro-Banner ───
                    FixFadeSlideIn(
                      delay: _at(2),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryContainer,
                              Color(0xFF006C4A),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -24,
                              bottom: -24,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.verified_rounded,
                                          color: AppColors.primaryFixedDim,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ZERO DELAY GUARANTEE',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: FixNowTypography.labelSmall.copyWith(
                                                color: AppColors.primaryFixedDim,
                                                letterSpacing: 0.8,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '15-Min Dispatch',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: FixNowTypography.headlineMd.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const _PingDot(
                                            color: AppColors.primaryFixed,
                                            size: 8,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'LIVE RADAR',
                                            style: FixNowTypography.dataMono.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ─── 4. Role Selection Section ───
                    FixFadeSlideIn(
                      delay: _at(3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'CHOOSE ACCOUNT MODE',
                                  style: FixNowTypography.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tap to select',
                                      style: FixNowTypography.bodySmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _StitchRoleCard(
                            title: 'I Need a Service',
                            subtitle: 'Homeowners & Residents',
                            description:
                                'Book verified electricians, plumbers & AC technicians '
                                'in 15 mins. Transparent pricing & 30-day warranty.',
                            tag: 'Popular',
                            benefitChips: const [
                              _BenefitChip(icon: Icons.schedule_rounded, text: '15-Min Arrival'),
                              _BenefitChip(icon: Icons.security_rounded, text: '30-Day Coverage'),
                            ],
                            icon: Icons.home_repair_service_rounded,
                            selected: _selected == AccountRole.customer,
                            onTap: () => setState(() => _selected = AccountRole.customer),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _StitchRoleCard(
                            title: 'I Am a Service Professional',
                            subtitle: 'Technicians, Contractors & Crews',
                            description:
                                'Join 5,000+ verified tradespeople. Instant daily '
                                'payouts, flexible hours & zero commission on spare parts.',
                            benefitChips: const [
                              _BenefitChip(icon: Icons.payments_rounded, text: 'Daily Payout'),
                              _BenefitChip(icon: Icons.percent_rounded, text: '0% Spares Cut'),
                            ],
                            icon: Icons.construction_rounded,
                            selected: _selected == AccountRole.providerApplicant,
                            onTap: () => setState(() => _selected = AccountRole.providerApplicant),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ─── 5. Action Controls ───
                    FixFadeSlideIn(
                      delay: _at(4),
                      child: Column(
                        children: [
                          FixPressable(
                            pressedScale: 0.99,
                            child: SizedBox(
                              height: 54,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => widget.onContinue(_selected, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                  elevation: 3,
                                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: FixNowTypography.button.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_ctaLabel),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account?',
                                style: FixNowTypography.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => widget.onContinue(_selected, false),
                                child: Text(
                                  'Sign in',
                                  style: FixNowTypography.headlineMd.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ─── 6. Trust Badges Strip ───
                    FixFadeSlideIn(
                      delay: _at(5),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppColors.outlineVariant.withValues(alpha: 0.4),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'TRUSTED SAFE NETWORK',
                                  style: FixNowTypography.dataMono.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppColors.outlineVariant.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTrustBadge(
                                  icon: Icons.fingerprint_rounded,
                                  badgeColor: AppColors.primaryFixed,
                                  iconColor: AppColors.onPrimaryFixed,
                                  title: 'UIDAI Aadhaar',
                                  subtitle: 'Verified Techs',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTrustBadge(
                                  icon: Icons.lock_rounded,
                                  badgeColor: AppColors.secondaryContainer,
                                  iconColor: AppColors.onSecondaryContainer,
                                  title: 'Escrow Held',
                                  subtitle: 'Pay Post-Job',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTrustBadge(
                                  icon: Icons.star_rounded,
                                  badgeColor: AppColors.tertiaryFixed,
                                  iconColor: AppColors.onTertiaryFixed,
                                  title: '4.9★ Rated',
                                  subtitle: '100K+ Repaired',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _buildTrustBadge({
    required IconData icon,
    required Color badgeColor,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, size: 16, color: iconColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: FixNowTypography.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: FixNowTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Stitch-accurate Role Card ───────────────────────────────────────────────
class _StitchRoleCard extends StatelessWidget {
  const _StitchRoleCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.tag,
    this.benefitChips = const [],
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? tag;
  final List<_BenefitChip> benefitChips;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$title. $description',
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.surfaceContainerLowest
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.08 : 0.03),
              blurRadius: selected ? 12 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: selected ? 1.0 : 0.9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: selected ? AppColors.onPrimary : AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      style: FixNowTypography.headlineMd.copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (tag != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryFixed,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        tag!,
                                        style: FixNowTypography.labelSmall.copyWith(
                                          color: AppColors.onPrimaryFixed,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: FixNowTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : AppColors.surfaceContainerHighest,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.onPrimary,
                            size: 16,
                          )
                        : null,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 56, top: 12),
                child: Text(
                  description,
                  style: FixNowTypography.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              if (benefitChips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 56, top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: benefitChips.map((chip) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.surfaceContainer
                              : AppColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(chip.icon, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              chip.text,
                              style: FixNowTypography.dataMono.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BenefitChip {
  const _BenefitChip({required this.icon, required this.text});
  final IconData icon;
  final String text;
}

// ─── _PingDot: Stitch animate-ping equivalent ────────────────────────────────
class _PingDot extends StatefulWidget {
  const _PingDot({
    this.color = AppColors.primary,
    this.size = 8.0,
  });

  final Color color;
  final double size;

  @override
  State<_PingDot> createState() => _PingDotState();
}

class _PingDotState extends State<_PingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!reduceMotion)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final scale = 1.0 + _controller.value * 1.5;
                  final opacity = (1.0 - _controller.value).clamp(0.0, 0.75);
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
