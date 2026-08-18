import 'package:flutter/material.dart';

abstract final class AppColors {
  static const backgroundPrimary = Color(0xFF07110F);
  static const backgroundSecondary = Color(0xFF0A1714);
  static const surfacePrimary = Color(0xFF10201C);
  static const surfaceSecondary = Color(0xFF152923);
  static const surfaceElevated = Color(0xFF1B332C);

  static const primary = Color(0xFF45E0A8);
  static const primaryHover = Color(0xFF62E8B8);
  static const primaryPressed = Color(0xFF29BC88);
  static const primarySoft = Color(0xFF153D31);
  static const onPrimary = Color(0xFF04120D);

  static const accentGold = Color(0xFFE5B869);
  static const accentGoldHover = Color(0xFFF0CA85);
  static const accentGoldSoft = Color(0xFF2D2516);
  static const onAccentGold = Color(0xFF1F1604);

  static const cream = Color(0xFFFAF8F5);
  static const creamMuted = Color(0xFFE8E4DC);
  static const surfaceCream = Color(0xFFF3ECE0);

  static const textPrimary = Color(0xFFF5FBF8);
  static const textSecondary = Color(0xFFB5C8C1);
  static const textMuted = Color(0xFF82978F);
  static const textDisabled = Color(0xFF62736D);

  static const borderDefault = Color(0xFF274139);
  static const borderStrong = Color(0xFF3B5C51);
  static const borderGold = Color(0xFF5C4825);
  static const focus = Color(0xFF79F0C4);

  static const success = Color(0xFF45E0A8);
  static const successSoft = Color(0xFF143C30);
  static const warning = Color(0xFFF2B84B);
  static const warningSoft = Color(0xFF3C3018);
  static const danger = Color(0xFFF06A6A);
  static const dangerSoft = Color(0xFF432224);
  static const emergency = Color(0xFFE14B55);
  static const emergencySoft = Color(0xFF462126);
  static const info = Color(0xFF78B7FF);
  static const infoSoft = Color(0xFF19324B);
  static const verified = Color(0xFF45E0A8);
  static const rating = Color(0xFFF2C45C);
  static const scrim = Color(0xA3000705);

  // Compatibility aliases keep feature code semantic while it migrates in
  // bounded screen tasks.
  static const background = backgroundPrimary;
  static const surface = surfacePrimary;
  static const border = borderDefault;
}
