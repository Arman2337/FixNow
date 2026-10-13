import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';

/// Bundled font family name. Must match the `family:` string declared for the
/// Inter assets in `pubspec.yaml` character-for-character, or Flutter silently
/// falls back to the platform face.
const String kFixNowFontFamily = 'Inter';

abstract final class FixNowTypography {
  static TextStyle _inter(
    double size,
    FontWeight weight,
    double height, [
    double letterSpacing = 0.0,
    Color color = AppColors.textPrimary,
  ]) {
    return TextStyle(
      fontFamily: kFixNowFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static final TextStyle displayLarge = _inter(
    32,
    FontWeight.w700,
    1.15,
    -0.3,
  );
  static final TextStyle displayMedium = _inter(
    28,
    FontWeight.w700,
    1.2,
    -0.3,
  );

  static final TextStyle h1 = _inter(26, FontWeight.w700, 1.2, -0.2);
  static final TextStyle h2 = _inter(24, FontWeight.w700, 1.25);
  static final TextStyle h3 = _inter(20, FontWeight.w600, 1.3);
  static final TextStyle h4 = _inter(18, FontWeight.w600, 1.3);

  static final TextStyle bodyLarge = _inter(16, FontWeight.w400, 1.5);
  static final TextStyle bodyMedium = _inter(14, FontWeight.w400, 1.5);
  static final TextStyle bodySmall = _inter(13, FontWeight.w400, 1.45);

  static final TextStyle labelLarge = _inter(14, FontWeight.w600, 1.0);
  static final TextStyle labelMedium = _inter(12, FontWeight.w600, 1.0);
  static final TextStyle labelSmall = _inter(
    11,
    FontWeight.w500,
    1.0,
    0.4,
  ); // small uppercase labels get +0.4 spacing

  static final TextStyle button = _inter(15, FontWeight.w600, 1.1);
  static final TextStyle buttonSecondary = _inter(15, FontWeight.w600, 1.1);
  static final TextStyle buttonSmall = _inter(13, FontWeight.w600, 1.1);

  static final TextStyle priceLarge = _inter(24, FontWeight.w700, 1.2);
  static final TextStyle priceMedium = _inter(20, FontWeight.w700, 1.2);
  static final TextStyle priceSmall = _inter(16, FontWeight.w600, 1.2);

  static final TextStyle status = _inter(12, FontWeight.w600, 1.0);
  static final TextStyle badge = _inter(11, FontWeight.w600, 1.0);

  // Expose text theme mapping to integrate with standard Material ThemeData
  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
    displayLarge: displayLarge.copyWith(color: primary),
    displayMedium: displayMedium.copyWith(color: primary),
    headlineLarge: h1.copyWith(color: primary),
    headlineMedium: h2.copyWith(color: primary),
    headlineSmall: h3.copyWith(color: primary),
    titleLarge: h4.copyWith(color: primary),
    bodyLarge: bodyLarge.copyWith(color: primary),
    bodyMedium: bodyMedium.copyWith(color: primary),
    bodySmall: bodySmall.copyWith(color: secondary),
    labelLarge: labelLarge.copyWith(color: primary),
    labelMedium: labelMedium.copyWith(color: secondary),
    labelSmall: labelSmall.copyWith(color: secondary),
  );

  // Backward compatibility aliases
  static TextStyle get headlineXl => displayLarge;
  static TextStyle get headlineLg => displayMedium;
  static TextStyle get headlineMd => h1;
  static TextStyle get display => displayLarge;
  static TextStyle get heading1 => h1;
  static TextStyle get heading2 => h2;
  static TextStyle get heading3 => h3;
  static TextStyle get title => h4;
  static TextStyle get body => bodyMedium;
  static TextStyle get label => labelLarge;
  static TextStyle get caption => bodySmall;
  static TextStyle get priceDisplay => priceLarge;
  static TextStyle get dataMono => labelSmall;
}
