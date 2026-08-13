import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x52000000), blurRadius: 8, offset: Offset(0, 3)),
  ];

  static const floating = <BoxShadow>[
    BoxShadow(color: Color(0x70000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const modal = <BoxShadow>[
    BoxShadow(color: Color(0x8F000000), blurRadius: 40, offset: Offset(0, 16)),
  ];
}
