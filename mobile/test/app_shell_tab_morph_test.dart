import 'package:fixnow_mobile/app/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stateful probe so the test can verify the tab's State survives switching
/// away and back (the whole point of animating inside IndexedStack).
class _Probe extends StatefulWidget {
  const _Probe({required this.label});
  final String label;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(widget.label),
      ElevatedButton(
        onPressed: () => setState(() => _taps += 1),
        child: Text('add ${widget.label}'),
      ),
      if (_taps > 0) Text('kept: $_taps'),
    ],
  );
}

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

void main() {
  // FlutterSecureStorage has no test shim by default — mock the channel.
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => null);

  testWidgets('switching tabs reveals the new pane and settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AppShell(
          customerHome: const _Probe(label: 'Home pane'),
          customerBookings: const _Probe(label: 'Bookings pane'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home pane'), findsOneWidget);
    expect(find.text('Bookings pane'), findsNothing);

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();

    expect(find.text('Bookings pane'), findsOneWidget);
    expect(find.text('Home pane'), findsNothing);
  });

  testWidgets('tab state survives switching away and back', (tester) async {
    await tester.pumpWidget(
      _host(
        AppShell(
          customerHome: const _Probe(label: 'Home pane'),
          customerBookings: const _Probe(label: 'Bookings pane'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('add Home pane'));
    await tester.pump();
    expect(find.text('kept: 1'), findsOneWidget);

    // Away…
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Home pane'), findsNothing);

    // …and back: the pane's State must still be alive.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home pane'), findsOneWidget);
    expect(find.text('kept: 1'), findsOneWidget);
  });

  testWidgets('reduce motion reveals panes with no animation', (tester) async {
    await tester.pumpWidget(
      _host(
        AppShell(
          customerHome: const _Probe(label: 'Home pane'),
          customerBookings: const _Probe(label: 'Bookings pane'),
        ),
        disableAnimations: true,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Bookings'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Bookings pane'), findsOneWidget);
  });
}
