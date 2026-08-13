import 'package:fixnow_mobile/app/app_navigation.dart';
import 'package:fixnow_mobile/app/app_shell_controller.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_bottom_navigation.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    this.role = AppShellRole.customer,
    this.controller,
    this.customerHome,
    this.customerProfile,
    this.customerBookings,
    super.key,
  });

  final AppShellRole role;
  final AppShellController? controller;
  final Widget? customerHome;
  final Widget? customerProfile;
  final Widget? customerBookings;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppShellController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _setController(widget.controller);
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _setController(widget.controller);
    }
  }

  void _setController(AppShellController? controller) {
    _ownsController = controller == null;
    _controller = controller ?? AppShellController();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = AppNavigation.forRole(widget.role);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selectedIndex = _controller.selectedIndex;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: FixPageFrame(
              child: IndexedStack(
                index: selectedIndex,
                children: [
                  for (var index = 0; index < destinations.length; index += 1)
                    if (widget.role == AppShellRole.customer &&
                        index == 0 &&
                        widget.customerHome != null)
                      widget.customerHome!
                    else if (widget.role == AppShellRole.customer &&
                        index == 1 &&
                        widget.customerBookings != null)
                      widget.customerBookings!
                    else if (widget.role == AppShellRole.customer &&
                        index == 3 &&
                        widget.customerProfile != null)
                      widget.customerProfile!
                    else
                      _ShellDestination(label: destinations[index].label),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: FixBottomNavigation(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                _controller.selectDestination(
                  index,
                  destinationCount: destinations.length,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ShellDestination extends StatelessWidget {
  const _ShellDestination({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FixPageHeader(
            eyebrow: 'FixNow care',
            title: label,
            description: label == 'Help'
                ? 'Clear guidance when you need a hand.'
                : 'This area is being prepared.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          FixCard(
            semanticLabel: '$label section',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  label == 'Help'
                      ? Icons.support_agent_rounded
                      : Icons.construction_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(_messageFor(label))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _messageFor(String label) => switch (label) {
    'Help' =>
      'Support is not available in this preview yet. If anyone is in immediate danger, contact local emergency services.',
    _ => 'This area is not available in this preview yet.',
  };
}
