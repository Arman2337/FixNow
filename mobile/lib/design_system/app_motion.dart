import 'package:flutter/animation.dart';

/// Motion tokens for FixNow.
///
/// Durations escalate with the visual weight of the change: [fast] for direct
/// touch feedback, [standard] for most state changes, [emphasis] for moments
/// that should feel deliberate, and [container] for surfaces that grow or move.
/// [celebrate] is reserved for the few rewarding beats (booking accepted, a
/// rating tapped, a job completed) that are allowed a little overshoot.
abstract final class AppMotion {
  // Durations.
  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 200);
  static const emphasis = Duration(milliseconds: 300);
  static const container = Duration(milliseconds: 340);

  /// Ambient, always-on loops (emergency pulse, live "on air" dot).
  static const pulse = Duration(milliseconds: 1600);

  /// One sweep of a skeleton shimmer highlight.
  static const shimmer = Duration(milliseconds: 1200);

  /// Delay added per item in a staggered list entrance.
  static const staggerStep = Duration(milliseconds: 60);

  // Curves.
  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;
  static const standardCurve = Curves.easeInOutCubic;

  /// Overshoot curve for the rewarding beats. Use sparingly.
  static const celebrateCurve = Curves.easeOutBack;

  /// Symmetric ease for ambient loops.
  static const pulseCurve = Curves.easeInOut;
}
