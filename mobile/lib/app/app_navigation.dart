import 'package:flutter/material.dart';

enum AppShellRole { customer, provider }

@immutable
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

abstract final class AppNavigation {
  static const customer = <AppDestination>[
    AppDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    AppDestination(
      label: 'Bookings',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    AppDestination(
      label: 'Help',
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent_rounded,
    ),
    AppDestination(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  static const provider = <AppDestination>[
    AppDestination(
      label: 'Home',
      icon: Icons.work_outline_rounded,
      selectedIcon: Icons.work_rounded,
    ),
    AppDestination(
      label: 'Active Job',
      icon: Icons.navigation_outlined,
      selectedIcon: Icons.navigation_rounded,
    ),
    AppDestination(
      label: 'Earnings',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
    ),
    AppDestination(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  static List<AppDestination> forRole(AppShellRole role) => switch (role) {
    AppShellRole.customer => customer,
    AppShellRole.provider => provider,
  };
}
