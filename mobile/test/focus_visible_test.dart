import 'dart:io';

import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// MOB-006.
///
/// Five widgets had independently restated a text field's border in a way that
/// deleted the focus indicator: the login form passed `BorderSide.none`, and four
/// others put a borderless `TextField` inside a `Container` that had no way to
/// know its child had focus. None of those are compile errors or even visible in
/// a screenshot - the field simply never says where the caret is.
///
/// The first group of tests is behavioural: it focuses a real field and looks at
/// the rendered border, because "the code no longer says `BorderSide.none`" is a
/// statement about the code, not about the user.
///
/// The second group is a source gate, because the behavioural tests can only
/// cover the widgets someone remembered to write a test for, and the failure mode
/// here is precisely a widget nobody thought needed a test.
void main() {
  group('focus indicator is rendered', () {
    Future<void> pumpInApp(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(child: SizedBox(width: 320, child: child)),
          ),
        ),
      );
    }

    BorderSide borderOfFirst(WidgetTester tester) {
      final input = tester.widget<InputDecorator>(find.byType(InputDecorator));
      final border = input.decoration.focusedBorder;
      return border is OutlineInputBorder
          ? border.borderSide
          : const BorderSide(color: Colors.transparent);
    }

    testWidgets('FixTextField shows the theme focus ring when focused', (
      tester,
    ) async {
      await pumpInApp(tester, const FixTextField(label: 'Mobile number'));

      // The rendered InputDecorator is the thing the user sees, so read the
      // resting border off it rather than off the widget's own configuration.
      final restingBefore = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration
          .enabledBorder;
      expect(
        restingBefore,
        isNot(equals(const BorderSide())),
        reason: 'a resting field must still have a visible boundary',
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      final focused = borderOfFirst(tester);
      expect(focused.color, AppColors.focus);
      expect(focused.width, 2.0);
    });

    testWidgets('FixSearchField ring appears on focus and is not just its '
        'resting border', (tester) async {
      await pumpInApp(tester, const FixSearchField(hintText: 'Search'));

      BorderSide restingBorder() {
        final box = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decoration = box.decoration as BoxDecoration;
        return (decoration.border as Border).top;
      }

      final resting = restingBorder();
      expect(resting.color, isNot(AppColors.focus));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      final focused = restingBorder();
      expect(focused.color, AppColors.focus);
      expect(focused.width, 2.0);
    });
  });

  group('theme declares the focus ring', () {
    test('focusedBorder is focus at 2px', () {
      final focused =
          AppTheme.dark.inputDecorationTheme.focusedBorder!
              as OutlineInputBorder;
      expect(focused.borderSide.color, AppColors.focus);
      expect(focused.borderSide.width, 2.0);
    });

    test('resting border is declared, not absent', () {
      final theme = AppTheme.dark.inputDecorationTheme;
      expect(theme.border, isNotNull);
      expect(theme.enabledBorder, isNotNull);
      expect(theme.border, isNot(InputBorder.none));
      expect(theme.enabledBorder, isNot(InputBorder.none));
    });
  });

  group('source gate', () {
    late List<File> sources;

    setUpAll(() {
      sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    });

    test('there are sources to check', () {
      expect(sources.length, greaterThan(50));
    });

    test('no text field restates its border as BorderSide.none', () {
      // `borderSide: BorderSide.none` is the pattern that deleted the ring on the
      // login form. A button's `side:` is a different property and is allowed.
      final offenders = <String>[];
      for (final file in sources) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('borderSide: BorderSide.none')) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'A restated border with no side removes the focus ring. Delete the '
            'override and let AppTheme.dark.inputDecorationTheme draw it: '
            '${offenders.join(', ')}',
      );
    });

    test('a field may only be borderless inside FixFocusBorder', () {
      // `InputBorder.none` on a field is legitimate exactly when a surrounding
      // widget owns the border and reacts to focus. FixFocusBorder is that
      // widget.
      //
      // A file is permitted when it is the component itself, or when every
      // borderless field in it is matched by a FixFocusBorder in the same file.
      // Counting rather than a bare `contains` matters: a file that adopts the
      // component for one field would otherwise get a blanket pass, and the
      // regression this gate exists to stop is exactly "someone added a second
      // field to a file we already fixed".
      //
      // The exemptions are per-file and carry the reason, because the one real
      // case is not a workaround: a hidden field the platform keyboard and
      // screen reader drive, whose visible boxes draw the active position
      // themselves.
      const exemptions = <String, String>{
        'lib/features/provider/provider_active_job_cockpit_screen.dart':
            'the OTP field sits inside Opacity(0); the six visible boxes paint '
            'the active position from _otpValue.length',
      };
      const owner = 'lib/design_system/fix_components.dart';

      final offenders = <String>[];
      for (final file in sources) {
        final path = file.path.replaceAll('\\', '/');
        if (path.endsWith(owner)) continue;
        if (exemptions.containsKey(path)) continue;

        final text = file.readAsStringSync();
        final borderlessFields = 'focusedBorder: InputBorder.none'
            .allMatches(text)
            .length;
        if (borderlessFields == 0) continue;

        final owners = 'FixFocusBorder('.allMatches(text).length;
        if (owners < borderlessFields) {
          offenders.add(
            '${file.path}: $borderlessFields borderless field(s) but only '
            '$owners FixFocusBorder',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'A field with InputBorder.none needs a FixFocusBorder in the same '
            'file to own its border and react to focus. Either wrap it, or '
            'delete the three InputBorder.none lines and let the theme draw '
            'them.\n${offenders.join('\n')}',
      );

      // Every exemption must still describe live code, or the gate is guarding
      // a comment about something that has moved.
      for (final entry in exemptions.entries) {
        expect(
          File(entry.key).existsSync(),
          isTrue,
          reason:
              'exemption for ${entry.key} is stale - ${entry.value} - and '
              'should be deleted',
        );
      }
    });

    test('FixTextField does not restate the borders the theme owns', () {
      // The value was not the problem - 1.5px against the theme's 2px. The
      // problem was restating it, because the next person to change the ring
      // changes the theme and this keeps the old one.
      final source = File(
        'lib/design_system/fix_components.dart',
      ).readAsStringSync();
      final start = source.indexOf('class FixTextField');
      final end = source.indexOf('class FixSearchField');
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final body = source.substring(start, end);
      expect(
        body,
        isNot(contains('focusedBorder')),
        reason: 'FixTextField must inherit focusedBorder from the theme',
      );
    });
  });
}
