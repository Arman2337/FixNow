import 'package:flutter/widgets.dart';

abstract final class AppRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const card = 16.0;
  static const large = 20.0;
  static const bottomSheet = 24.0;
  static const pill = 999.0;

  static const buttonBorder = BorderRadius.all(Radius.circular(medium));
  static const inputBorder = BorderRadius.all(Radius.circular(medium));
  static const cardBorder = BorderRadius.all(Radius.circular(card));
  static const sheetBorder = BorderRadius.vertical(top: Radius.circular(bottomSheet));
}
