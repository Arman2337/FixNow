import 'package:fixnow_mobile/app/app_navigation.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:flutter/material.dart';

class FixBottomNavigation extends StatelessWidget {
  const FixBottomNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        for (var i = 0; i < destinations.length; i++)
          NavigationDestination(
            icon: Icon(destinations[i].icon),
            // Keyed on selection so the glyph pops each time this tab becomes
            // active. The M3 pill indicator already slides on its own.
            selectedIcon: FixScaleIn(
              key: ValueKey('fix-nav-$i-${selectedIndex == i}'),
              from: 0.7,
              child: Icon(destinations[i].selectedIcon),
            ),
            label: destinations[i].label,
            tooltip: destinations[i].label,
          ),
      ],
    );
  }
}
