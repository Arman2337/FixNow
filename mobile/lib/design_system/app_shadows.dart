import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x1A142033), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const floating = <BoxShadow>[
    BoxShadow(color: Color(0x24142033), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static const modal = <BoxShadow>[
    BoxShadow(color: Color(0x33142033), blurRadius: 40, offset: Offset(0, 16)),
  ];
}
