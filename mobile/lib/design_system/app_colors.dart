import 'package:flutter/material.dart';

abstract final class AppColors {
  // Approved reference direction: navy framing, white information surfaces,
  // and cobalt actions. Feature code must consume these semantic names.
  static const backgroundPrimary = Color(0xFF081020);
  static const backgroundSecondary = Color(0xFF14213D);
  static const surfacePrimary = Color(0xFFF7F7FA);
  static const surfaceSecondary = Color(0xFFE2E6EF);
  static const surfaceElevated = Color(0xFF14213D);

  static const primary = Color(0xFF2857F5);
  static const primaryHover = Color(0xFF4E8CFF);
  static const primaryPressed = Color(0xFF1E43C9);
  static const primarySoft = Color(0xFFDDE7FF);
  static const onPrimary = Color(0xFFFFFFFF);

  static const accentGold = Color(0xFFF59E0B);
  static const accentGoldHover = Color(0xFFFBBF24);
  static const accentGoldSoft = Color(0xFFFFF3D6);
  static const onAccentGold = Color(0xFF3D2600);

  static const cream = Color(0xFFFFFFFF);
  static const creamMuted = Color(0xFFF1F3F8);
  static const surfaceCream = Color(0xFFF7F7FA);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFC8D1E6);
  static const textMuted = Color(0xFF93A0BA);
  static const textDisabled = Color(0xFF6D7890);
  static const textOnSurface = Color(0xFF172035);
  static const textOnSurfaceSecondary = Color(0xFF596579);
  static const textOnSurfaceMuted = Color(0xFF6D7890);

  // Explicit foreground contracts prevent a page-level dark theme from
  // leaking unreadable text into a light component surface.
  static const textOnDarkPrimary = textPrimary;
  static const textOnDarkSecondary = textSecondary;
  static const textOnDarkMuted = textMuted;
  static const textOnLightPrimary = textOnSurface;
  static const textOnLightSecondary = textOnSurfaceSecondary;
  static const textOnLightMuted = textOnSurfaceMuted;
  static const iconOnDark = textOnDarkPrimary;
  static const iconOnLight = textOnLightPrimary;
  static const primaryButtonText = onPrimary;
  static const dangerButtonText = onPrimary;
  static const selectedLightCardText = textOnLightPrimary;
  static const selectedLightCardSecondaryText = textOnLightSecondary;
  static const inputText = textOnLightPrimary;
  static const inputLabel = textOnLightSecondary;
  static const inputHint = textOnLightMuted;
  static const inputIcon = textOnLightSecondary;

  static const borderDefault = Color(0xFFD5DAE5);
  static const borderStrong = Color(0xFFB7C1D4);
  static const borderGold = Color(0xFFF3C56A);
  static const focus = Color(0xFF4E8CFF);

  static const success = Color(0xFF1F9D68);
  static const successSoft = Color(0xFFE0F4EA);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFFF3D6);
  static const danger = Color(0xFFFF4D4F);
  static const dangerSoft = Color(0xFFFFE5E5);
  static const emergency = Color(0xFFFF4D4F);
  static const emergencySoft = Color(0xFFFFE5E5);
  static const info = Color(0xFF4E8CFF);
  static const infoSoft = Color(0xFFDDE7FF);
  static const verified = Color(0xFF1F9D68);
  static const rating = Color(0xFFF59E0B);
  static const scrim = Color(0xB3081020);

  // Compatibility aliases keep feature code semantic while it migrates in
  // bounded screen tasks.
  static const background = backgroundPrimary;
  static const surface = surfacePrimary;
  static const border = borderDefault;
}
