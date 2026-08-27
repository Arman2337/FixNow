import 'dart:async';

import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/signature_motion.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onGetStarted,
    required this.onSignIn,
    super.key,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  /// Entrance delay for the block at [slot] on the 60ms stagger clock.
  static Duration _at(int slot) => AppMotion.staggerStep * slot;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // First-load choreography. The page assembles top-to-bottom on a
          // 60ms stagger clock, but it isn't the same motion on every block —
          // uniform entrances read as "basic". Two signature beats carry the
          // craft: the headline (slots 2-3) rises line-by-line from behind a
          // mask, and the hero icon pops with a gentle overshoot just after its
          // card (slot 1) lands. The CTAs (slots 8-9) stay calm and arrive
          // last, so the eye settles on "Get started". Everything degrades to a
          // static layout under reduce-motion.
          final headlineStyle = Theme.of(context).textTheme.displayLarge
              ?.copyWith(color: AppColors.cream, height: 1.15);

          return SingleChildScrollView(
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
                    FixFxZoomIn(
                      delay: _at(0),
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: FixBrandMark(),
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight < 700 ? 40 : 80),
                    FixFadeSlideIn(
                      delay: _at(1),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: AppRadius.cardBorder,
                          border: Border.all(color: AppColors.borderStrong),
                        ),
                        child: Row(
                          children: [
                            // Overshoot pop, landing a beat after the card.
                            FixScaleIn(
                              from: 0.8,
                              delay: _at(1) + const Duration(milliseconds: 160),
                              child: const _WelcomeHeroIcon(),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            const Expanded(
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
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // Signature beat: the headline rises line-by-line from
                    // behind a mask (slots 2-3).
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RisingText(
                          'Trusted help.',
                          style: headlineStyle,
                          delay: _at(2),
                        ),
                        _RisingText(
                          'When you need it.',
                          style: headlineStyle,
                          delay: _at(3),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FixFadeSlideIn(
                      delay: _at(4),
                      child: Text(
                        'Book reliable local professionals, see clear updates, and stay in control from request to completion.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Trust pills cascade in one at a time (slots 5-7).
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FixFadeSlideIn(
                          delay: _at(5),
                          child: _buildTrustPill(
                            Icons.verified_user_rounded,
                            'Verified professionals',
                          ),
                        ),
                        FixFadeSlideIn(
                          delay: _at(6),
                          child: _buildTrustPill(
                            Icons.route_outlined,
                            'Live job updates',
                          ),
                        ),
                        FixFadeSlideIn(
                          delay: _at(7),
                          child: _buildTrustPill(
                            Icons.shield_outlined,
                            'Work-start OTP',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    FixFadeSlideIn(
                      delay: _at(8),
                      child: FixButton(
                        label: 'Get started',
                        onPressed: onGetStarted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FixFadeSlideIn(
                      delay: _at(9),
                      child: FixButton(
                        label: 'Sign in',
                        onPressed: onSignIn,
                        variant: FixButtonVariant.secondary,
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

/// A single line of text that rises up from behind a clip mask — the welcome
/// hero's signature entrance beat. Transform + opacity only; the [ClipRect]
/// hides the line until it slides up into its own box. Renders statically
/// under reduce-motion.
class _RisingText extends StatefulWidget {
  const _RisingText(
    this.text, {
    required this.style,
    this.delay = Duration.zero,
  });

  final String text;
  final TextStyle? style;
  final Duration delay;

  @override
  State<_RisingText> createState() => _RisingTextState();
}

class _RisingTextState extends State<_RisingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _startDelay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.container,
    );
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve);
    // Full own-height rise, clipped to the line box, so the words emerge from
    // beneath their own baseline rather than sliding in from empty space.
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(_fade);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _startDelay = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(widget.text, style: widget.style);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return text;
    return ClipRect(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: text),
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
