import 'package:flutter/widgets.dart';

abstract final class AppRadius {
  static const small = 6.0;
  static const medium = 10.0;
  static const card = 14.0;
  static const large = 20.0;
  static const pill = 999.0;

  static const buttonBorder = BorderRadius.all(Radius.circular(medium));
  static const inputBorder = BorderRadius.all(Radius.circular(medium));
  static const cardBorder = BorderRadius.all(Radius.circular(card));
}
