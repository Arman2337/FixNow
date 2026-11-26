import 'package:fixnow_mobile/design_system/folding_rule_opening.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  VoidCallback onFinished, {
  bool reduced = false,
  VoidCallback? onTap,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(onTap: onTap, child: const Text('Destination')),
        FoldingRuleOpening(onFinished: onFinished),
      ],
    ),
  ),
);

void main() {
  testWidgets('finishes on the first frame after 2.4 seconds', (tester) async {
    var finished = 0;
    await tester.pumpWidget(_host(() => finished++));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2399));
    expect(finished, 0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(finished, 1);
  });

  testWidgets('reduced motion uses a 120 ms fade', (tester) async {
    var finished = 0;
    await tester.pumpWidget(_host(() => finished++, reduced: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 119));
    expect(finished, 0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(finished, 1);
  });

  testWidgets('blocks taps behind the opening and skips once', (tester) async {
    var finished = 0;
    var taps = 0;
    await tester.pumpWidget(_host(() => finished++, onTap: () => taps++));
    await tester.tapAt(const Offset(36, 36));
    expect(taps, 0);
    await tester.tap(find.text('Skip'));
    expect(finished, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(finished, 1);
  });
}
