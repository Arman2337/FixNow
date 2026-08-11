import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const _fontFamily = 'Inter';
  static const _fallback = <String>['Roboto', 'SF Pro Text', 'sans-serif'];

  static const display = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const heading1 = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const heading2 = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 4 / 3,
  );
  static const heading3 = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const title = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 4 / 3,
  );
  static const bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 14 / 9,
  );
  static const body = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const label = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 10 / 7,
  );
  static const caption = TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 4 / 3,
  );

  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
    displayLarge: display.copyWith(color: primary),
    headlineLarge: heading1.copyWith(color: primary),
    headlineMedium: heading2.copyWith(color: primary),
    headlineSmall: heading3.copyWith(color: primary),
    titleMedium: title.copyWith(color: primary),
    bodyLarge: bodyLarge.copyWith(color: primary),
    bodyMedium: body.copyWith(color: primary),
    labelLarge: label.copyWith(color: primary),
    bodySmall: caption.copyWith(color: secondary),
    labelSmall: caption.copyWith(color: secondary),
  );
}
