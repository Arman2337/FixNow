import 'package:fixnow_mobile/app/app_navigation.dart';
import 'package:fixnow_mobile/app/app_shell_controller.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_bottom_navigation.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    this.role = AppShellRole.customer,
    this.controller,
    this.customerHome,
    this.customerProfile,
    this.customerBookings,
    this.customerHelp,
    this.providerHome,
    this.providerJobs,
    this.providerHistory,
    this.providerProfile,
    super.key,
  });

  final AppShellRole role;
  final AppShellController? controller;
  final Widget? customerHome;
  final Widget? customerProfile;
  final Widget? customerBookings;
  final Widget? customerHelp;
  final Widget? providerHome;
  final Widget? providerJobs;
  final Widget? providerHistory;
  final Widget? providerProfile;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _storage = FlutterSecureStorage();
  late AppShellController _controller;
  late bool _ownsController;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _setController(widget.controller);
    _restoreSelectedDestination();
  }

  String get _storageKey => 'fixnow.navigation.${widget.role.name}';

  Future<void> _restoreSelectedDestination() async {
    final saved = await _storage.read(key: _storageKey);
    final index = int.tryParse(saved ?? '');
    if (!mounted || index == null) return;
    _controller.selectDestination(
      index,
      destinationCount: AppNavigation.forRole(widget.role).length,
    );
  }

  Future<void> _saveSelectedDestination(int index) =>
      _storage.write(key: _storageKey, value: '$index');

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

  Widget _destinationFor(int index) {
    if (widget.role == AppShellRole.customer && index == 0) {
      return widget.customerHome ?? _ShellDestination(label: 'Home');
    }
    if (widget.role == AppShellRole.customer && index == 1) {
      return widget.customerBookings ?? _ShellDestination(label: 'Bookings');
    }
    if (widget.role == AppShellRole.customer && index == 2) {
      return widget.customerHelp ?? _ShellDestination(label: 'Help');
    }
    if (widget.role == AppShellRole.customer && index == 3) {
      return widget.customerProfile ?? _ShellDestination(label: 'Profile');
    }
    if (widget.role == AppShellRole.provider && index == 0) {
      return widget.providerHome ?? _ShellDestination(label: 'Jobs');
    }
    if (widget.role == AppShellRole.provider && index == 1) {
      return widget.providerJobs ?? _ShellDestination(label: 'Requests');
    }
    if (widget.role == AppShellRole.provider && index == 2) {
      return widget.providerHistory ?? _ShellDestination(label: 'History');
    }
    if (widget.role == AppShellRole.provider && index == 3) {
      return widget.providerProfile ?? _ShellDestination(label: 'Profile');
    }
    return _ShellDestination(label: 'FixNow');
  }

  @override
  Widget build(BuildContext context) {
    final destinations = AppNavigation.forRole(widget.role);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selectedIndex = _controller.selectedIndex;
        // Direction of the tab morph: higher index = forward.
        final forward = selectedIndex >= _lastIndex;
        _lastIndex = selectedIndex;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: FixPageFrame(
              child: IndexedStack(
                index: selectedIndex,
                children: [
                  for (var index = 0; index < destinations.length; index += 1)
                    _TabReveal(
                      active: index == selectedIndex,
                      forward: forward,
                      child: _destinationFor(index),
                    ),
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
                _saveSelectedDestination(index);
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

/// Directional entrance for a tab pane. Lives INSIDE the IndexedStack, so
/// every tab keeps its State, scroll position, and muted tickers. The widget
/// tree shape is IDENTICAL whether active or not (always wrapped in
/// Fade+Slide) — switching the wrapper type on activation would tear down the
/// pane's subtree and destroy its state.
class _TabReveal extends StatefulWidget {
  const _TabReveal({
    required this.active,
    required this.forward,
    required this.child,
  });

  final bool active;
  final bool forward;
  final Widget child;

  @override
  State<_TabReveal> createState() => _TabRevealState();
}

class _TabRevealState extends State<_TabReveal>
    with SingleTickerProviderStateMixin {
  // Created eagerly: a late-final lazy construct would first build its ticker
  // inside dispose() (inactive panes), looking up ancestors on a dead tree.
  late final AnimationController _controller;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.fast);
    // Park at 1.0: the pane is fully visible; IndexedStack unpaints inactive
    // panes regardless.
    _controller.value = 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(_TabReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active && !_reduce) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween(
          begin: Offset(widget.forward ? 0.05 : -0.05, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve),
        ),
        child: widget.child,
      ),
    );
  }
}
