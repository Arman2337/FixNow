import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const _headingFontFamily = 'Playfair Display';
  static const _headingFallback = <String>['Georgia', 'Times New Roman', 'serif'];

  static const _bodyFontFamily = 'Inter';
  static const _bodyFallback = <String>['Roboto', 'SF Pro Text', 'sans-serif'];

  static const display = TextStyle(
    fontFamily: _headingFontFamily,
    fontFamilyFallback: _headingFallback,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );
  static const heading1 = TextStyle(
    fontFamily: _headingFontFamily,
    fontFamilyFallback: _headingFallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
  );
  static const heading2 = TextStyle(
    fontFamily: _headingFontFamily,
    fontFamilyFallback: _headingFallback,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const heading3 = TextStyle(
    fontFamily: _headingFontFamily,
    fontFamilyFallback: _headingFallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static const title = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: _bodyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static const bodyLarge = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: _bodyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );
  static const body = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: _bodyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const label = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: _bodyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const caption = TextStyle(
    fontFamily: _bodyFontFamily,
    fontFamilyFallback: _bodyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
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
