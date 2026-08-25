import 'dart:async';

import 'package:fixnow_mobile/notifications/push_enrollment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeForegroundSource implements ForegroundPushSource {
  final controller = StreamController<ForegroundPushMessage>.broadcast();

  @override
  Stream<ForegroundPushMessage> foregroundMessages() => controller.stream;

  void emit(ForegroundPushMessage message) => controller.add(message);
}

void main() {
  testWidgets('foreground pushes surface as an in-app banner while the app is open',
      (tester) async {
    final source = FakeForegroundSource();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();

    final subscription = bindForegroundPushBanner(
      source: source,
      messengerKey: messengerKey,
      featureEnabled: true,
    );
    addTearDown(() => subscription?.cancel());

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    source.emit(
      const ForegroundPushMessage(title: 'FixNow', body: 'A provider accepted your request.'),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('A provider accepted your request.'),
      findsOneWidget,
    );
  });

  testWidgets('binding is inert when the push feature is compiled out',
      (tester) async {
    final source = FakeForegroundSource();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();

    final subscription = bindForegroundPushBanner(
      source: source,
      messengerKey: messengerKey,
      featureEnabled: false,
    );
    addTearDown(source.controller.close);

    expect(subscription, isNull);

    // No listener attached; emitting must not throw.
    source.emit(
      const ForegroundPushMessage(title: 'FixNow', body: 'ignored'),
    );
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    expect(find.textContaining('ignored'), findsNothing);
  });
}
