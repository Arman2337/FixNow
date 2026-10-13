import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_active_booking_island.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('island shows service, status and arrival copy', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FixActiveBookingIsland(
          serviceLabel: 'Plumbing · Leaking tap',
          statusLabel: fixActiveBookingStatusLabel('EN_ROUTE'),
          etaText: '6 min',
          initial: 'Suresh',
          onTap: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Plumbing · Leaking tap'), findsOneWidget);
    expect(find.text('On the way to you'), findsOneWidget);
    expect(find.text('6 min'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('island exposes a semantic label for screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FixActiveBookingIsland(
          serviceLabel: 'Cleaning · Deep clean',
          statusLabel: fixActiveBookingStatusLabel('ASSIGNED'),
          etaText: '10 min',
          initial: 'Ravi',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Assert on the Semantics wrapper that owns the label, rather than the
    // merged semantics tree, so the contract is explicit: status and arrival
    // are spoken, not just displayed.
    final label = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label)
        .whereType<String>()
        .join(' | ');
    expect(
      label,
      contains('Active booking: Cleaning · Deep clean'),
    );
    expect(label, contains('Pro assigned'));
    expect(label, contains('arriving in 10 min'));
  });

  testWidgets('island tap fires the callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        FixActiveBookingIsland(
          serviceLabel: 'Plumbing',
          statusLabel: fixActiveBookingStatusLabel('IN_PROGRESS'),
          onTap: () => taps += 1,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Plumbing'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('island hides the chevron when there is nowhere to go', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const FixActiveBookingIsland(
          serviceLabel: 'Plumbing',
          statusLabel: 'Finding a pro nearby',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('island falls back to a neutral initial', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FixActiveBookingIsland(
          serviceLabel: 'Plumbing',
          statusLabel: 'Finding a pro nearby',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(fixActiveBookingInitial(null), '•');
    expect(fixActiveBookingInitial(''), '•');
    expect(fixActiveBookingInitial(' suresh '), 'S');
  });

  testWidgets('island renders static under reduced motion', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(
          FixActiveBookingIsland(
            serviceLabel: 'Plumbing',
            statusLabel: fixActiveBookingStatusLabel('EN_ROUTE'),
            onTap: () {},
          ),
        ),
      ),
    );
    // No pump-and-settle dance needed: the entrance is skipped entirely.
    await tester.pump();
    expect(find.text('On the way to you'), findsOneWidget);
    expect(tester.getSemantics(find.text('On the way to you')), isNotNull);
  });

  test('status labels are plain language for every booking state', () {
    expect(fixActiveBookingStatusLabel('REQUESTED'), 'Finding a pro nearby');
    expect(fixActiveBookingStatusLabel('ASSIGNED'), 'Pro assigned');
    expect(fixActiveBookingStatusLabel('EN_ROUTE'), 'On the way to you');
    expect(fixActiveBookingStatusLabel('IN_PROGRESS'), 'Work in progress');
    expect(fixActiveBookingStatusLabel('SOMETHING_NEW'), 'Booking update');
  });
}
