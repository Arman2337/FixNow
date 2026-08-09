import 'package:fixnow_mobile/app/app.dart';
import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the minimal FixNow foundation', (tester) async {
    await tester.pumpWidget(
      const FixNowApp(environment: AppEnvironment.development),
    );

    expect(find.text('FixNow'), findsOneWidget);
  });

  testWidgets('hides the debug banner in production', (tester) async {
    await tester.pumpWidget(
      const FixNowApp(environment: AppEnvironment.production),
    );

    expect(find.byType(Banner), findsNothing);
  });
}
