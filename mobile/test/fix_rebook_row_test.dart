import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/services/rebook_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CustomerBooking _booking({
  String id = 'b1',
  String status = 'COMPLETED',
  DateTime? createdAt,
  String categoryId = 'cat-plumbing',
  String description = 'Leaking tap',
}) => CustomerBooking(
  id: id,
  serviceCategoryId: categoryId,
  status: status,
  description: description,
  createdAt: createdAt ?? DateTime.now(),
  version: 1,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('row renders nothing without completed bookings', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FixRebookRow(
          bookings: const [],
          categoryName: (_) => 'Plumbing',
          onBookAgain: (_) {},
        ),
      ),
    );
    expect(find.text('Your recent services, one tap away'), findsNothing);
  });

  testWidgets('row ignores bookings that are not completed', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FixRebookRow(
          bookings: [
            _booking(id: 'a', status: 'EN_ROUTE'),
            _booking(id: 'b', status: 'CANCELLED'),
          ],
          categoryName: (_) => 'Plumbing',
          onBookAgain: (_) {},
        ),
      ),
    );
    expect(find.text('Your recent services, one tap away'), findsNothing);
  });

  testWidgets('row offers at most three completed bookings', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FixRebookRow(
          bookings: [
            _booking(id: 'a', description: 'Tap repair'),
            _booking(id: 'b', description: 'Drain cleaning'),
            _booking(id: 'c', description: 'Geyser check'),
            _booking(id: 'd', description: 'Older job'),
          ],
          categoryName: (_) => 'Plumbing',
          onBookAgain: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Section header plus at most three cards; the fourth booking is dropped.
    expect(find.text('Your recent services, one tap away'), findsOneWidget);
    expect(find.byType(FixCard), findsNWidgets(3));
    expect(find.widgetWithText(FilledButton, 'Book again'), findsNWidgets(3));
  });

  testWidgets('book-again button reports the booking it belongs to', (
    tester,
  ) async {
    CustomerBooking? rebooked;
    await tester.pumpWidget(
      _wrap(
        FixRebookRow(
          bookings: [_booking(id: 'target')],
          categoryName: (_) => 'Plumbing',
          onBookAgain: (booking) => rebooked = booking,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final cta = find.widgetWithText(FilledButton, 'Book again');
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pump();
    expect(rebooked?.id, 'target');
  });

  testWidgets('row shows a relative age, not a raw date', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FixRebookRow(
          bookings: [_booking(createdAt: DateTime.now())],
          categoryName: (_) => 'Cleaning',
          onBookAgain: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Completed today'), findsOneWidget);
  });

  test('age label covers today through months', () {
    final now = DateTime(2026, 10, 8, 12);
    String labelFor(DateTime date) => fixRebookAgeLabel(date, now: now);

    expect(labelFor(DateTime(2026, 10, 8, 3)), 'Completed today');
    expect(labelFor(DateTime(2026, 10, 7, 23)), 'Completed yesterday');
    expect(labelFor(DateTime(2026, 10, 4)), 'Completed 4 days ago');
    expect(labelFor(DateTime(2026, 10, 1)), 'Completed last week');
    expect(labelFor(DateTime(2026, 9, 20)), 'Completed 2 weeks ago');
    expect(labelFor(DateTime(2026, 7, 8)), 'Completed 3 months ago');
  });

  testWidgets('row survives long text and 200% text scale', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _wrap(
          FixRebookRow(
            bookings: [
              _booking(
                description: 'A very long problem description that must clip',
              ),
            ],
            categoryName: (_) =>
                'Averyveryverylongcategorynameherethatclips',
            onBookAgain: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // The card still renders; long values clip rather than overflow.
    expect(tester.takeException(), isNull);
    expect(find.byType(FixCard), findsOneWidget);
  });
}
