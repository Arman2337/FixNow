import 'package:fixnow_mobile/app/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      onDestinationSelected: (index) {
        if (index != selectedIndex) {
          HapticFeedback.selectionClick();
        }
        onDestinationSelected(index);
      },
      destinations: [
        for (var i = 0; i < destinations.length; i++)
          NavigationDestination(
            icon: Icon(destinations[i].icon),
            // Keyed on selection with elastic micro-spring pop on tap
            selectedIcon: TweenAnimationBuilder<double>(
              key: ValueKey('fix-nav-$i-${selectedIndex == i}'),
              tween: Tween(begin: 0.65, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: Icon(destinations[i].selectedIcon),
            ),
            label: destinations[i].label,
            tooltip: destinations[i].label,
          ),
      ],
    );
  }
}
