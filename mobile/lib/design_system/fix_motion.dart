import 'dart:math' as math;

import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:flutter/material.dart';

/// Reusable, dependency-free motion primitives for FixNow.
///
/// Every widget here degrades to a static presentation when the platform has
/// "reduce motion" enabled (`MediaQuery.disableAnimations`), so the app stays
/// usable and accessible. Timings and curves come from [AppMotion] so motion
/// stays consistent with the design system.
bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Adds a subtle "press in" scale to any tappable child.
///
/// Uses a [Listener] rather than a [GestureDetector] so it never steals taps
/// from the child (an [InkWell], button, etc. underneath still fires normally).
class FixPressable extends StatefulWidget {
  const FixPressable({
    required this.child,
    this.pressedScale = 0.96,
    this.duration = AppMotion.fast,
    super.key,
  });

  final Widget child;
  final double pressedScale;
  final Duration duration;

  @override
  State<FixPressable> createState() => _FixPressableState();
}

class _FixPressableState extends State<FixPressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: AppMotion.enterCurve,
        child: widget.child,
      ),
    );
  }
}

/// A calm, always-on pulse. Used for ambient signals such as the emergency
/// affordance or a live "on air" indicator — never for decoration.
class FixPulse extends StatefulWidget {
  const FixPulse({
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 1.05,
    this.duration = AppMotion.pulse,
    super.key,
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;

  @override
  State<FixPulse> createState() => _FixPulseState();
}

class _FixPulseState extends State<FixPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.pulseCurve,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read reduce-motion here (MediaQuery isn't available in initState) and
    // keep the ticker itself idle when motion is disabled — not just hidden.
    if (_reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final scale =
            widget.minScale + (widget.maxScale - widget.minScale) * _curve.value;
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

/// Sweeps a soft highlight band diagonally/horizontally across [child].
/// Backs both [FixShimmer] (skeleton loading) and slower "shine" accents.
class _Sweep extends StatefulWidget {
  const _Sweep({
    required this.child,
    required this.duration,
    required this.highlight,
    required this.begin,
    required this.end,
    this.band = 0.35,
  });

  final Widget child;
  final Duration duration;
  final double highlight;
  final Alignment begin;
  final Alignment end;
  final double band;

  @override
  State<_Sweep> createState() => _SweepState();
}

class _SweepState extends State<_Sweep> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep the sweep ticker idle (not just invisible) under reduce-motion.
    if (_reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    final band = widget.band;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Band centre travels from just off the leading edge to off the far
        // edge, so the highlight enters and exits cleanly.
        final centre = _controller.value * (1 + 2 * band) - band;
        final s1 = (centre - band).clamp(0.0, 1.0);
        final s2 = centre.clamp(0.0, 1.0);
        final s3 = (centre + band).clamp(0.0, 1.0);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: widget.begin,
            end: widget.end,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: widget.highlight),
              Colors.transparent,
            ],
            stops: [s1, s2, s3],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// Loading shimmer. Wrap a solid placeholder box (or group of them) to give it
/// a moving highlight instead of a bare, static grey block.
class FixShimmer extends StatelessWidget {
  const FixShimmer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => _Sweep(
    duration: AppMotion.shimmer,
    highlight: 0.30,
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    band: 0.35,
    child: child,
  );
}

/// One-shot scale-in with a gentle overshoot. Good for badges, checkmarks, and
/// small elements that should feel like they "land".
class FixScaleIn extends StatefulWidget {
  const FixScaleIn({
    required this.child,
    this.from = 0.0,
    this.duration = AppMotion.emphasis,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final double from;
  final Duration duration;
  final Duration delay;

  @override
  State<FixScaleIn> createState() => _FixScaleInState();
}

class _FixScaleInState extends State<FixScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: widget.from,
    end: 1.0,
  ).animate(
    CurvedAnimation(parent: _controller, curve: AppMotion.celebrateCurve),
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// One-shot fade + rise used for list/section entrances. Pass an increasing
/// [delay] per item to produce a staggered reveal.
class FixFadeSlideIn extends StatefulWidget {
  const FixFadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.container,
    this.offsetY = 0.12,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Starting vertical offset as a fraction of the child's height.
  final double offsetY;

  @override
  State<FixFadeSlideIn> createState() => _FixFadeSlideInState();
}

class _FixFadeSlideInState extends State<FixFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enterCurve,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(0, widget.offsetY),
    end: Offset.zero,
  ).animate(_fade);
  Timer? _startDelay;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      // A cancellable timer, so a disposed widget never starts its ticker.
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
    if (_reduceMotion(context)) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// A number that rolls up to its target instead of snapping — for invoice
/// totals, ETAs, and other figures that change in front of the user.
class FixCountUp extends StatelessWidget {
  const FixCountUp({
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 0,
    this.style,
    this.duration = AppMotion.container,
    this.curve = AppMotion.enterCurve,
    super.key,
  });

  final num value;
  final String prefix;
  final String suffix;
  final int fractionDigits;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final target = value.toDouble();
    if (_reduceMotion(context)) {
      return Text(
        '$prefix${target.toStringAsFixed(fractionDigits)}$suffix',
        style: style,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: duration,
      curve: curve,
      builder: (context, animated, _) => Text(
        '$prefix${animated.toStringAsFixed(fractionDigits)}$suffix',
        style: style,
      ),
    );
  }
}

/// A star that pops when it becomes filled — the satisfying feedback on a
/// rating input. Swaps between a filled and outline glyph.
class FixAnimatedStar extends StatefulWidget {
  const FixAnimatedStar({
    required this.filled,
    this.size = 36.0,
    this.color,
    this.filledIcon = Icons.star_rounded,
    this.outlineIcon = Icons.star_outline_rounded,
    super.key,
  });

  final bool filled;
  final double size;
  final Color? color;
  final IconData filledIcon;
  final IconData outlineIcon;

  @override
  State<FixAnimatedStar> createState() => _FixAnimatedStarState();
}

class _FixAnimatedStarState extends State<FixAnimatedStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.emphasis,
  );

  @override
  void didUpdateWidget(covariant FixAnimatedStar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.filled && widget.filled) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.filled ? widget.filledIcon : widget.outlineIcon,
      size: widget.size,
      color: widget.color,
    );
    if (_reduceMotion(context)) return icon;
    return AnimatedBuilder(
      animation: _controller,
      child: icon,
      builder: (context, child) {
        // 0 -> peak -> 0 bump, so the star swells then settles back.
        final bump = math.sin(_controller.value * math.pi) * 0.35;
        return Transform.scale(scale: 1 + bump, child: child);
      },
    );
  }
}
