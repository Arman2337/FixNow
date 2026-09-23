import 'package:flutter/material.dart';

abstract final class AppColors {
  // Stitch Design System: FixNow Trust Matrix
  // Modern, high-trust on-demand utility aesthetic.
  // Primary Emerald (#006948 / #059669), Slate (#0F172A), Crisp canvas neutrals (#F8F9FF).

  // Foundations & Surfaces
  static const background = Color(0xFFF8F9FF);
  static const backgroundPrimary = Color(0xFFF8F9FF);
  static const backgroundSecondary = Color(0xFF0F172A);
  static const surface = Color(0xFFF8F9FF);
  static const surfacePrimary = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFEFF4FF);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFEFF4FF);
  static const surfaceContainer = Color(0xFFE5EEFF);
  static const surfaceContainerHigh = Color(0xFFDCE9FF);
  static const surfaceContainerHighest = Color(0xFFD3E4FE);
  static const inverseSurface = Color(0xFF213145);
  static const inverseOnSurface = Color(0xFFEAF1FF);

  // Primary: Emerald
  static const primary = Color(0xFF006948);
  static const primaryEmerald = Color(0xFF059669);
  static const primaryHover = Color(0xFF047857);
  static const primaryPressed = Color(0xFF0A5C36);
  static const primarySoft = Color(0xFFECFDF5);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF00855D);
  static const onPrimaryContainer = Color(0xFFF5FFF7);
  static const primaryFixed = Color(0xFF85F8C4);
  static const primaryFixedDim = Color(0xFF68DBA9);
  static const onPrimaryFixed = Color(0xFF002114);

  // Secondary: Obsidian Slate
  static const secondary = Color(0xFF565E74);
  static const secondarySlate = Color(0xFF0F172A);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFDAE2FD);
  static const onSecondaryContainer = Color(0xFF5C647A);

  // Tertiary / Accent Gold
  static const tertiary = Color(0xFF825100);
  static const accentGold = Color(0xFFF59E0B);
  static const accentGoldHover = Color(0xFFFBBF24);
  static const accentGoldSoft = Color(0xFFFFFBEB);
  static const onAccentGold = Color(0xFF2A1700);
  static const tertiaryContainer = Color(0xFFA36700);
  static const onTertiaryContainer = Color(0xFFFFFBFF);
  static const tertiaryFixed = Color(0xFFFFDDB8);
  static const onTertiaryFixed = Color(0xFF2A1700);

  // Neutrals & Text
  static const textPrimary = Color(0xFF0B1C30);
  static const textSecondary = Color(0xFF565E74);
  static const textTertiary = Color(0xFF8E97A6);
  static const textMuted = Color(0xFF6D7A72);
  static const textDisabled = Color(0xFF94A3B8);
  static const textOnSurface = Color(0xFF0B1C30);
  static const textOnSurfaceSecondary = Color(0xFF565E74);
  static const textOnSurfaceMuted = Color(0xFF5D6A82);

  // Foregrounds
  static const textOnDarkPrimary = Color(0xFFFFFFFF);
  static const textOnDarkSecondary = Color(0xFFCBD5E1);
  static const textOnDarkMuted = Color(0xFF94A3B8);
  static const textOnLightPrimary = Color(0xFF0B1C30);
  static const textOnLightSecondary = Color(0xFF565E74);
  static const textOnLightMuted = Color(0xFF5D6A82);
  static const iconOnDark = Color(0xFFFFFFFF);
  static const iconOnLight = Color(0xFF0B1C30);
  static const primaryButtonText = Color(0xFFFFFFFF);
  static const dangerButtonText = Color(0xFFFFFFFF);
  static const selectedLightCardText = Color(0xFF006948);
  static const selectedLightCardSecondaryText = Color(0xFF565E74);
  static const inputText = Color(0xFF0B1C30);
  static const inputLabel = Color(0xFF0F172A);
  static const inputHint = Color(0xFF94A3B8);
  static const inputIcon = Color(0xFF565E74);

  // Borders & Outlines
  static const border = Color(0xFFE2E8F0);
  static const borderDefault = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const borderGold = Color(0xFFFDE68A);
  static const outline = Color(0xFF6D7A72);
  static const outlineVariant = Color(0xFFBCCAC0);
  static const focus = Color(0xFF059669);

  // Status & Semantics
  static const success = Color(0xFF059669);
  static const successSoft = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFFFBEB);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEF2F2);
  static const emergency = Color(0xFFDC2626);
  static const emergencySoft = Color(0xFFFEF2F2);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onError = Color(0xFFFFFFFF);
  static const onErrorContainer = Color(0xFF93000A);
  static const info = Color(0xFF0284C7);
  static const infoSoft = Color(0xFFEFF4FF);
  static const verified = Color(0xFF059669);
  static const rating = Color(0xFFF59E0B);

  // High contrast on-light states
  static const ratingOnLight = Color(0xFF92400E);
  static const warningOnLight = Color(0xFF92400E);
  static const dangerOnLight = Color(0xFF991B1B);
  static const successOnLight = Color(0xFF065F46);
  static const infoOnLight = Color(0xFF0369A1);

  // Live / Active ping
  static const live = Color(0xFF10B981);
  static const liveSoft = Color(0xFFD1FAE5);
  static const scrim = Color(0x660F172A);

  // Backward compatibility aliases
  static const cream = Color(0xFFFFFFFF);
  static const creamMuted = Color(0xFFF8FAFC);
  static const surfaceCream = Color(0xFFFFFFFF);
}
