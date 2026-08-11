import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

class FixCard extends StatelessWidget {
  const FixCard({required this.child, this.semanticLabel, super.key});

  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: child,
      ),
    );
    return semanticLabel == null
        ? card
        : Semantics(container: true, label: semanticLabel, child: card);
  }
}
