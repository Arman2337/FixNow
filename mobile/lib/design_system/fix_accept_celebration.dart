import 'dart:async';
import 'dart:math' as math;

import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen celebrate beat shown the moment a provider accepts a booking.
///
/// The one rewarding beat per booking: confetti (transform + opacity only),
/// a spring checkmark, and a haptic. Degrades to a static banner with no
/// timer or painter when `MediaQuery.disableAnimations` is set, matching the
/// [MatchRadarView] reduce-motion contract. Tap anywhere to dismiss early.
class FixAcceptCelebration extends StatefulWidget {
  const FixAcceptCelebration({
    required this.onDismiss,
    this.serviceName,
    super.key,
  });

  final VoidCallback onDismiss;

  /// Optional category name surfaced in the subtitle.
  final String? serviceName;

  @override
  State<FixAcceptCelebration> createState() => _FixAcceptCelebrationState();
}

class _FixAcceptCelebrationState extends State<FixAcceptCelebration>
    with SingleTickerProviderStateMixin {
  // Nullable: never created under reduce motion, and creating a ticker during
  // dispose (late-final trap) would look up ancestors on a dead tree.
  AnimationController? _confetti;
  Timer? _autoDismiss;
  bool _reduceMotion = false;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armed) return;
    _armed = true;
    // Inherited-widget reads belong here, not initState. Static banner under
    // reduce motion — dismiss by tap only, no pending timer.
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion) return;
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
    _autoDismiss = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _confetti?.dispose();
    super.dispose();
  }

  void _dismiss() {
    _autoDismiss?.cancel();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scrim,
      child: GestureDetector(
        onTap: _dismiss,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!_reduceMotion)
              AnimatedBuilder(
                animation: _confetti!,
                builder: (context, _) => CustomPaint(
                  size: MediaQuery.sizeOf(context),
                  painter: _ConfettiPainter(progress: _confetti!.value),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: _reduceMotion
                  ? _banner()
                  : FixScaleIn(from: 0.6, child: _banner()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner() => Container(
    constraints: const BoxConstraints(maxWidth: 380),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.large),
      border: Border.all(color: AppColors.borderDefault),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Live Status Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Match Confirmed',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'FIXNOW LIVE',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Spring Ripple Checkmark Icon
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        Text(
          'Provider accepted!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.serviceName == null
              ? 'Your professional is on it — tap to keep going.'
              : 'Your ${widget.serviceName} pro is on it — tap to keep going.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.3,
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Verified Trust Badges Strip (responsive Wrap)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            _buildMiniTrustBadge(Icons.shield_rounded, 'Aadhaar Verified'),
            _buildMiniTrustBadge(Icons.verified_user_rounded, 'Police Checked'),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // High Visibility ETA Strip (FittedBox to guarantee zero overflow)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.near_me_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ETA ~15 Mins',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12),
                Text(
                  'Dispatched to your gate',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildMiniTrustBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Deterministic confetti: seeded particles so tests and sessions render the
/// same burst. Transform + opacity only — translate/rotate per particle, no
/// blend modes, no saveLayer.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress}) : _particles = _buildParticles();

  final double progress;
  final List<_Particle> _particles;

  static List<_Particle> _buildParticles() {
    final random = math.Random(7);
    const palette = [
      AppColors.accentGold,
      AppColors.accentGoldHover,
      AppColors.primary,
      AppColors.primaryHover,
      AppColors.live,
      AppColors.cream,
    ];
    return List.generate(28, (i) {
      final angle = random.nextDouble() * math.pi * 2;
      return _Particle(
        angle: angle,
        distance: 90 + random.nextDouble() * 130,
        size: 5 + random.nextDouble() * 6,
        rotation: (random.nextDouble() - 0.5) * math.pi * 3,
        color: palette[i % palette.length],
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2 - 40);
    for (final particle in _particles) {
      // Ease-out distance so the burst feels explosive, then settles.
      final eased = 1 - math.pow(1 - progress, 3).toDouble();
      final offset = Offset(
        math.cos(particle.angle) * particle.distance * eased,
        math.sin(particle.angle) * particle.distance * eased +
            40 * progress, // gentle gravity
      );
      final paint = Paint()
        ..color = particle.color.withValues(
          alpha: progress < 0.6 ? 1 : 1 - (progress - 0.6) / 0.4,
        );
      canvas
        ..save()
        ..translate(center.dx + offset.dx, center.dy + offset.dy)
        ..rotate(particle.rotation * progress)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 0.55,
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.rotation,
    required this.color,
  });

  final double angle;
  final double distance;
  final double size;
  final double rotation;
  final Color color;
}
