import 'dart:convert';
import 'dart:io';

import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/fix_active_booking_island.dart';
import 'package:fixnow_mobile/design_system/fix_before_after_slider.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
import 'package:fixnow_mobile/design_system/fix_eta_ring.dart';
import 'package:fixnow_mobile/design_system/fix_saved_data_banner.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/accessibility_harness.dart';

/// FN-141. Two halves, in this order on purpose.
///
/// **First: prove the harness can fail.** Every check below is run against a
/// deliberately broken widget and asserted to *throw*. A harness that checks
/// nothing and a harness that works produce identical output on a healthy app,
/// so a gate that only ever runs the happy path is indistinguishable from one
/// that stopped looking — the same trap the secret scanner's `--self-test`
/// closes in `scripts/scan-secrets.mjs`.
///
/// **Second: run the harness over the real components** and over the coverage
/// map that keeps new ones from slipping through.
void main() {
  group('the harness detects real violations', () {
    testWidgets('a tap target below 48px fails the size check', (tester) async {
      await tester.pumpForAccessibility(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ),
          ),
        ),
      );

      await expectCheckFails(
        () => tester.expectMinimumTouchTargets(screen: 'a 32px icon button'),
        because: 'a 32×32 icon button is below the 48×48 minimum and must '
            'fail the size check',
      );
    });

    testWidgets('a full-size control passes the same check', (tester) async {
      await tester.pumpForAccessibility(
        Scaffold(
          body: Center(
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
          ),
        ),
      );

      tester.expectMinimumTouchTargets(screen: 'a default icon button');
    });

    testWidgets('an unlabelled tappable control fails the label check', (
      tester,
    ) async {
      await tester.pumpForAccessibility(
        Scaffold(
          body: Center(
            // No text anywhere in the subtree, so there is nothing for a screen
            // reader to announce. A GestureDetector wrapping a Text would not do:
            // the text becomes the name, however unhelpful that name is.
            child: GestureDetector(
              onTap: () {},
              child: Container(width: 120, height: 120, color: AppColors.primary),
            ),
          ),
        ),
      );

      await expectCheckFails(
        () => tester.expectActionsAreLabelled(screen: 'a bare gesture detector'),
        because: 'a tappable region with no text and no semantics announces as '
            'an unlabelled button and must fail the label check',
      );
    });

    testWidgets('a labelled tappable control passes the same check', (
      tester,
    ) async {
      await tester.pumpForAccessibility(
        Scaffold(
          body: Center(
            child: Semantics(
              button: true,
              label: 'Rate this pro five stars',
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(width: 120, height: 120, child: Text('★')),
              ),
            ),
          ),
        ),
      );

      tester.expectActionsAreLabelled(screen: 'a labelled gesture detector');
    });

    testWidgets('text clipped by a narrow row fails the overflow check', (
      tester,
    ) async {
      await tester.pumpForAccessibility(
        Scaffold(
          body: Center(
            // A Row with a non-flexible long child is what overflows; a plain
            // Container with a short height merely clips, silently, which is
            // why this fixture is a Row rather than a box.
            child: Row(
              children: [
                const Text(
                  'A line of copy long enough that doubling its size cannot fit '
                  'beside its sibling.',
                ),
                Container(
                  width: 120,
                  height: 40,
                  color: AppColors.surfacePrimary,
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        () => tester.expectRendersWithoutOverflow(
          component: 'an overcrowded row',
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('focus that skips backwards fails the reading-order check', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Scaffold(
              body: Column(
                children: [
                  FocusTraversalOrder(
                    // Ascending on screen, descending on the keyboard.
                    order: const NumericFocusOrder(3),
                    child: const TextField(
                      key: _firstField,
                      decoration: InputDecoration(labelText: 'First'),
                    ),
                  ),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: const TextField(
                      key: _secondField,
                      decoration: InputDecoration(labelText: 'Second'),
                    ),
                  ),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: const TextField(
                      key: _thirdField,
                      decoration: InputDecoration(labelText: 'Third'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await expectCheckFails(
        () => tester.expectFocusOrder(
          const [_firstField, _secondField, _thirdField],
          screen: 'a deliberately reordered form',
        ),
        because: 'the form assigns descending traversal orders, so focus does '
            'not follow the visual reading order',
      );
    });

    testWidgets('focus in visual order passes the same check', (tester) async {
      await tester.pumpForAccessibility(
        Scaffold(
          body: Column(
            children: [
              const FixTextField(key: _firstField, label: 'Full name'),
              const FixTextField(key: _secondField, label: 'Mobile number'),
              FixButton(
                key: _saveButton,
                label: 'Save details',
                onPressed: _noop,
              ),
            ],
          ),
        ),
        textScale: 1,
      );

      await tester.expectFocusOrder(
        const [_firstField, _secondField, _saveButton],
        screen: 'the details form',
      );
    });

    test('low-contrast pairs fail the WCAG check', () {
      expect(
        () => expectMeetsWcagAa(
          // Gold on white is a decorative accent, not a text colour — which is
          // exactly why it must fail when used as one.
          AppColors.accentGold,
          AppColors.surfacePrimary,
          what: 'a deliberate low-contrast pair',
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('the contrast maths is the WCAG one, not an approximation', () {
      // Black on white is the 21:1 maximum and white on black the same; the
      // symmetric mid-grey pair is the documented 21/11 ≈ 1.91 case.
      expect(wcagContrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(
        wcagContrastRatio(Colors.white, Colors.black),
        closeTo(21, 0.01),
        reason: 'ratio must not depend on argument order',
      );
      expect(
        wcagContrastRatio(const Color(0xFF777777), Colors.white),
        closeTo(4.48, 0.02),
      );
      expect(describeColor(const Color(0xFF006948)), '#006948');
    });
  });

  group('audited components', () {
    /// The components the gate renders and checks on every run.
    ///
    /// Each entry is a real instance built from real data, not a placeholder:
    /// a fixture that cannot happen in production checks nothing.
    final components = <String, Widget Function()>{
      'FixButton': () => FixButton(label: 'Continue', onPressed: () {}),
      'FixCard (tappable)': () => FixCard(
        semanticLabel: 'Booking summary',
        onTap: () {},
        child: const Text('Leaking tap, 2 items'),
      ),
      'FixStatusChip': () => const FixStatusChip(
        label: 'Available',
        icon: Icons.check_circle_outline_rounded,
        tone: FixStatusTone.success,
      ),
      'FixEmptyState': () => const FixEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No bookings yet',
        message: 'Your bookings will appear here once you book a service.',
        actionLabel: 'Find a service',
        onAction: _noop,
      ),
      'FixErrorState': () => FixErrorState(
        title: 'Bookings unavailable',
        message: 'We could not load your bookings.',
        onRetry: _noop,
      ),
      'FixOfflineBanner': () => const FixOfflineBanner(),
      'FixStaleDataBanner': () =>
          FixStaleDataBanner(onRetry: _noop),
      'FixSavedDataBanner': () => FixSavedDataBanner(
        savedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        onRetry: _noop,
      ),
      'FixActiveBookingIsland': () => FixActiveBookingIsland(
        serviceLabel: 'Plumbing · Leaking tap',
        statusLabel: fixActiveBookingStatusLabel('EN_ROUTE'),
        etaText: '6 min',
        onTap: _noop,
      ),
      'FixEmergencyBanner': () =>
          FixEmergencyBanner(onCallNow: _noop, subtitle: 'Priority dispatch.'),
      'FixTextField': () => const FixTextField(label: 'Mobile number'),
      'FixSearchField': () => const FixSearchField(hintText: 'Search services'),
      'EtaProgressRing': () => const EtaProgressRing(minutes: 12),
      // FN-143. Exercised with real decoded bytes rather than a fake, because
      // `Image.memory` genuinely decodes and would otherwise fail on the
      // fixture rather than on the layout.
      'FixBeforeAfterSlider': () => FixBeforeAfterSlider(
        beforeBytes: _onePixelPng,
        afterBytes: _onePixelPng,
      ),
    };

    for (final entry in components.entries) {
      final name = entry.key;

      testWidgets('$name renders at 200% text without clipping', (tester) async {
        await tester.pumpForAccessibility(
          Scaffold(
            body: SingleChildScrollView(child: entry.value()),
          ),
        );
        tester.expectRendersWithoutOverflow(component: name);
      });

      testWidgets('$name names every control it exposes', (tester) async {
        await tester.pumpForAccessibility(
          Scaffold(
            body: SingleChildScrollView(child: entry.value()),
          ),
        );
        await tester.expectActionsAreLabelled(screen: name);
      });

      testWidgets('$name meets the 48px touch target minimum', (tester) async {
        await tester.pumpForAccessibility(
          Scaffold(
            body: SingleChildScrollView(child: entry.value()),
          ),
        );
        await tester.expectMinimumTouchTargets(screen: name);
      });
    }

    testWidgets('reading order follows the visual order of a form', (
      tester,
    ) async {
      await tester.pumpForAccessibility(
        Scaffold(
          body: Column(
            children: [
              const FixTextField(key: _firstField, label: 'Full name'),
              const FixTextField(key: _secondField, label: 'Mobile number'),
              FixButton(
                key: _saveButton,
                label: 'Save details',
                onPressed: _noop,
              ),
            ],
          ),
        ),
        textScale: 1,
      );

      await tester.expectFocusOrder(
        const [_firstField, _secondField, _saveButton],
        screen: 'the details form',
      );
    });
  });

  group('token contrast contract', () {
    // The pairs DESIGN.md §31 actually governs: body text on a surface, text on
    // a soft status chip, and the label on a filled button. Checked here with
    // one shared implementation instead of the copy that used to live in three
    // separate test files.
    test('body and secondary text clear AA on every light surface', () {
      const surfaces = [
        AppColors.surfacePrimary,
        AppColors.surfaceSecondary,
        AppColors.surfaceContainerLowest,
        AppColors.backgroundPrimary,
      ];
      const foregrounds = [
        AppColors.textPrimary,
        AppColors.textOnSurface,
        AppColors.textOnLightPrimary,
        AppColors.textSecondary,
      ];

      for (final foreground in foregrounds) {
        for (final surface in surfaces) {
          expectMeetsWcagAa(
            foreground,
            surface,
            what: '${describeColor(foreground)} on ${describeColor(surface)}',
          );
        }
      }
    });

    test('the filled-button label clears AA on the button colour', () {
      expectMeetsWcagAa(
        AppColors.onPrimary,
        AppColors.primary,
        what: 'the primary button label',
      );
      expectMeetsWcagAa(
        AppColors.onPrimary,
        AppColors.primaryHover,
        what: 'the hovered primary button label',
      );
    });

    test('the focus indicator clears 3:1 against the canvas', () {
      // WCAG 2.2 non-text contrast: a focus ring nobody can see is not a focus
      // ring, and DESIGN.md §31 calls this out separately from text contrast.
      expectMeetsWcagAa(
        AppColors.focus,
        AppColors.surfacePrimary,
        what: 'the focus indicator',
        largeText: true,
      );
    });

    test('on-light status steps clear AA on their soft chips and surfaces', () {
      const pairs = <(Color, Color)>[
        (AppColors.successOnLight, AppColors.successSoft),
        (AppColors.warningOnLight, AppColors.warningSoft),
        (AppColors.dangerOnLight, AppColors.dangerSoft),
        (AppColors.ratingOnLight, AppColors.accentGoldSoft),
        (AppColors.infoOnLight, AppColors.infoSoft),
      ];
      for (final (foreground, background) in pairs) {
        expectMeetsWcagAa(
          foreground,
          background,
          what: '${describeColor(foreground)} on ${describeColor(background)}',
        );
      }
    });

    test('every FixStatusChip tone clears AA on its own background', () {
      for (final tone in FixStatusTone.values) {
        final (foreground, background) = FixStatusChip.colorsFor(tone);
        expectMeetsWcagAa(
          foreground,
          background,
          what: 'the ${tone.name} status chip',
        );
      }
    });
  });

  group('coverage gate', () {
    late List<String> componentFiles;

    setUpAll(() {
      componentFiles = dartFilesIn('lib/design_system')
          .where((file) => !designSystemNonComponentFiles.contains(file))
          .toList();
    });

    test('there are component files to account for', () {
      expect(componentFiles.length, greaterThan(20));
      expect(designSystemNonComponentFiles, isNotEmpty);
    });

    test('every design-system component file declares its coverage', () {
      // The gate that makes this file more than a snapshot. A new component is
      // invisible to every check above until someone writes a fixture for it,
      // so the only honest thing to do is make that visible at build time.
      final undeclared = componentFiles
          .where((file) => !accessibilityCoverage.containsKey(file))
          .toList();

      expect(
        undeclared,
        isEmpty,
        reason:
            'These design-system files have no accessibilityCoverage entry, so '
            'no test can tell whether they were checked. Add one to '
            'test/support/accessibility_harness.dart: '
            'AccessibilityCoverage.audited() once a fixture below renders it, '
            'or AccessibilityCoverage.deferred("reason") if it is knowingly '
            'not audited yet.\n${undeclared.join('\n')}',
      );
    });

    test('every coverage entry points at a file that still exists', () {
      final orphaned = accessibilityCoverage.entries
          .where((entry) => !componentFiles.contains(entry.key))
          .map((entry) => entry.key)
          .toList();

      expect(
        orphaned,
        isEmpty,
        reason:
            'These entries name a component that was renamed or deleted, so '
            'they are guarding nothing. Delete the entry.\n'
            '${orphaned.join('\n')}',
      );
    });

    test('every deferred entry states a reason', () {
      final unreasoned = accessibilityCoverage.entries
          .where((entry) => !entry.value.isAudited)
          .where((entry) => (entry.value.reason ?? '').trim().length < 20)
          .map(
            (entry) =>
                '${entry.key} (${entry.value.reason ?? 'no reason given'})',
          )
          .toList();

      expect(
        unreasoned,
        isEmpty,
        reason:
            'Deferred accessibility coverage is only useful if the reason is '
            'written down. Anything shorter than a sentence is not a reason.\n'
            '${unreasoned.join('\n')}',
      );
    });

    test('the token files listed as non-components all exist', () {
      // Without this, a typo in designSystemNonComponentFiles would silently
      // exempt a component from the gate above.
      final missing = designSystemNonComponentFiles
          .where((file) => !File('lib/design_system/$file').existsSync())
          .toList();

      expect(missing, isEmpty, reason: missing.join('\n'));
    });
  });
}

const _firstField = Key('focus-order-first');
const _secondField = Key('focus-order-second');
const _thirdField = Key('focus-order-third');
const _saveButton = Key('focus-order-save');

/// A real 1×1 PNG, so `Image.memory` decodes instead of throwing on the fixture.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void _noop() {}