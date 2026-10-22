import 'dart:io';
import 'dart:math' as math;

import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// FN-141: the accessibility harness DESIGN.md §31 asks for.
///
/// DESIGN.md §31 requires four things of every surface: 4.5:1 contrast for
/// normal text and 3:1 for large text and meaningful boundaries, 48×48 touch
/// targets, semantic labels/roles/values/reading order, and no clipping at
/// accessibility text sizes. Before this file each of those was checked by hand
/// in whichever test happened to be open that day — the WCAG contrast formula
/// alone was copied into three different files, and nothing failed when a
/// component was added without a single one of the four.
///
/// So this is a harness, not a checklist:
///
/// * One implementation of each check, importable by any test.
/// * Failure messages that name the component, the colour values and the fix —
///   a gate whose message says "assertion failed" gets ignored within a week.
/// * A coverage map at the bottom of this file. Adding a component under
///   `lib/design_system/` without classifying it fails the build, which is what
///   makes this a gate rather than a snapshot that quietly stops describing the
///   app.
///
/// **What this harness cannot prove, stated plainly so nobody assumes
/// otherwise.** It renders through the widget tester, not through a device: it
/// does not exercise a real screen reader (TalkBack/VoiceOver), real platform
/// focus rings, gesture navigation, or the operating system's own text-scale
/// clamp. It checks that the semantics *tree* is well-formed and that text
/// survives 200% scaling inside the framework — which is the part regressions
/// actually break. Device-level verification stays a manual release step.

/// WCAG 2.2 minimum contrast for normal text.
const double kWcagAaNormalText = 4.5;

/// WCAG 2.2 minimum contrast for large text (>=24px, or >=18.66px bold) and for
/// meaningful UI boundaries and focus indicators.
const double kWcagAaLargeText = 3.0;

/// DESIGN.md §31: 48×48 touch targets on mobile.
const double kMinimumTouchTarget = 48;

/// The largest platform text size DESIGN.md §31 requires the app to survive.
const double kMaximumTextScale = 2.0;

/// WCAG relative luminance. Flutter's [Color.computeLuminance] implements the
/// sRGB formula already; this exists so there is one named entry point instead
/// of every caller reaching for the method and getting the constants wrong.
double wcagRelativeLuminance(Color color) => color.computeLuminance();

/// WCAG contrast ratio between two colours, from 1.0 to 21.0.
///
/// Order-independent, so callers cannot get it backwards.
double wcagContrastRatio(Color first, Color second) {
  final a = wcagRelativeLuminance(first);
  final b = wcagRelativeLuminance(second);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

/// Renders a colour as `#RRGGBB` so a failure names the exact value someone has
/// to go and change.
String describeColor(Color color) {
  String channel(double value) =>
      (value * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final rgb = '#${channel(color.r)}${channel(color.g)}${channel(color.b)}'
      .toUpperCase();
  return color.a < 1 ? '$rgb${channel(color.a)}' : rgb;
}

/// Asserts a foreground/background pair meets WCAG AA.
///
/// [what] names the pair in the failure message, which is the difference between
/// a gate people act on and one they route around.
void expectMeetsWcagAa(
  Color foreground,
  Color background, {
  required String what,
  bool largeText = false,
}) {
  final minimum = largeText ? kWcagAaLargeText : kWcagAaNormalText;
  final ratio = wcagContrastRatio(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(minimum),
    reason:
        '$what must meet WCAG AA ${largeText ? 'large' : 'normal'} text '
        '(>=${minimum.toStringAsFixed(1)}:1). ${describeColor(foreground)} on '
        '${describeColor(background)} is ${ratio.toStringAsFixed(2)}:1. Use the '
        'higher-contrast on-light step from AppColors, or change the surface.',
  );
}

/// Asserts that an accessibility check *fails* on a given fixture.
///
/// The harness is only trustworthy if it has been shown to fail on things that
/// are actually broken — a check that never throws is indistinguishable from a
/// check that stopped looking. [because] says which violation the fixture
/// contains, so a future edit that makes the fixture accidentally valid is
/// caught too.
///
/// Not an `expectLater`, deliberately: `expectLater` is itself guarded, and the
/// checks it would wrap pump the widget tester, which trips the guard.
Future<void> expectCheckFails(
  Future<void> Function() check, {
  required String because,
}) async {
  Object? caught;
  try {
    await check();
  } catch (error) {
    caught = error;
  }
  expect(caught, isA<TestFailure>(), reason: because);
}

/// The accessibility checks any widget test can run against its own tree.
extension AccessibilityAudit on WidgetTester {
  /// Pumps [child] the way an accessibility-conscious person has configured
  /// their device: 200% text by default, reduced motion, and an explicit narrow
  /// viewport so a component that only fits at 390pt is caught.
  ///
  /// Reduce-motion is declared because the design system's ambient tickers
  /// repeat forever; without it settling never completes and the test would
  /// fail for a reason unrelated to accessibility.
  Future<void> pumpForAccessibility(
    Widget child, {
    double textScale = kMaximumTextScale,
    Size viewport = const Size(320, 640),
  }) async {
    view.physicalSize = viewport;
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
    platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);

    await pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, widget) => MediaQuery(
          // Re-asserted inside the app: the ambient MediaQuery MaterialApp
          // builds would otherwise reset it and re-arm the looping tickers.
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: widget!,
        ),
        home: child,
      ),
    );
    await pump();
    await pumpAndSettle();
  }

  /// Fails on any layout overflow or framework exception raised while rendering.
  ///
  /// A RenderFlex overflow is reported through the exception pipeline rather
  /// than thrown where the caller can see it, so the harness drains it here and
  /// re-reports it with the component's name attached.
  void expectRendersWithoutOverflow({required String component}) {
    final exception = takeException();
    expect(
      exception,
      isNull,
      reason:
          '$component overflowed or threw while rendering. A control clipped '
          'at ${kMaximumTextScale.toStringAsFixed(0)}% text is unusable for '
          'someone who needs the larger text. Use Flexible/Expanded, wrap, or '
          'let the row grow instead of pinning a height.',
    );
  }

  /// Asserts every node a screen reader can activate announces itself.
  ///
  /// A control that can be tapped but carries no label is announced as
  /// "button" and nothing else — the user hears that *something* is there and
  /// cannot tell what it does.
  ///
  /// There is deliberately no exemption list. The failure mode of an exemption
  /// API is that it grows until nothing is checked; if a genuinely unlabelled
  /// node ever turns out to be correct, that is a conversation, not a default.
  Future<void> expectActionsAreLabelled({required String screen}) async {
    final handle = ensureSemantics();
    try {
      await pump();
      final offenders = <String>[
        for (final node in _actionableNodes())
          if (!_isAnnounceable(node)) node.describe(screen),
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            '$screen exposes controls a screen reader cannot name. Each is '
            'announced as an unlabelled button and nothing more. Wrap it in '
            'Semantics(label: ...) or give it a tooltip.\n'
            '${offenders.join('\n')}',
      );
    } finally {
      handle.dispose();
    }
  }

  /// Asserts every actionable node meets [kMinimumTouchTarget].
  ///
  /// DESIGN.md §31 sets 48×48 for mobile. An icon button sized to its glyph is
  /// the usual offender: it looks right and is unusable for anyone with a
  /// tremor or a large system font.
  ///
  /// [exempt] exists only for the rare control that is genuinely smaller and
  /// sits inside a larger one; it takes the node's rect so the decision is made
  /// against what the user can actually hit.
  Future<void> expectMinimumTouchTargets({
    required String screen,
    double minimum = kMinimumTouchTarget,
    bool Function(Rect rect)? exempt,
  }) async {
    final handle = ensureSemantics();
    try {
      await pump();
      final tooSmall = <String>[];
      for (final node in _actionableNodes()) {
        final rect = node.rect;
        // A zero rect means the node has not been laid out. Flagging it would
        // make the check noisy and therefore ignorable.
        if (rect.width <= 0 || rect.height <= 0) continue;
        if (rect.width + 0.5 >= minimum && rect.height + 0.5 >= minimum) {
          continue;
        }
        if (exempt != null && exempt(rect)) continue;
        tooSmall.add(
          '  - ${node.describe(screen)} is '
          '${rect.width.toStringAsFixed(1)}×'
          '${rect.height.toStringAsFixed(1)}, below '
          '${minimum.toStringAsFixed(0)}×${minimum.toStringAsFixed(0)}',
        );
      }
      expect(
        tooSmall,
        isEmpty,
        reason:
            '$screen has touch targets below ${minimum.toStringAsFixed(0)}px. '
            'Constrain the control to at least '
            '${minimum.toStringAsFixed(0)}×${minimum.toStringAsFixed(0)}, or '
            'use MaterialTapTargetSize.padded.\n${tooSmall.join('\n')}',
      );
    } finally {
      handle.dispose();
    }
  }

  /// Walks Tab focus through the tree and returns the keys of the controls it
  /// lands on, in the order a keyboard user reaches them.
  ///
  /// Keys rather than labels or rects: a focused text field exposes its name
  /// on a node the framework does not surface at the focus boundary, and the
  /// focused render object is the editable area inside the decoration rather
  /// than the field. Neither identifies the control the user thinks they moved
  /// to. A key does.
  Future<List<Key?>> tabFocusKeys(List<Key> candidates) async {
    final order = <Key?>[];
    for (var step = 0; step < candidates.length; step += 1) {
      await sendKeyEvent(LogicalKeyboardKey.tab);
      await pump();
      order.add(_focusedCandidate(candidates));
    }
    return order;
  }

  /// Asserts Tab visits [expectedKeys] in exactly that order.
  ///
  /// This is the check for DESIGN.md §31's logical reading order: focus has to
  /// follow the visual order, or a keyboard user is sent back up the page after
  /// reaching the bottom of it. Each key goes on the control itself, so the
  /// assertion is "focus reached this control next" rather than "focus moved".
  Future<void> expectFocusOrder(
    List<Key> expectedKeys, {
    required String screen,
  }) async {
    for (final key in expectedKeys) {
      expect(
        find.byKey(key).evaluate().isNotEmpty,
        isTrue,
        reason:
            '$screen declares focus stop $key, but nothing in its tree '
            'carries that key',
      );
    }

    final actual = await tabFocusKeys(expectedKeys);

    expect(
      actual,
      expectedKeys,
      reason:
          '$screen moves focus in an order that does not match its reading '
          'order. A keyboard or screen-reader user should reach '
          '$expectedKeys, but focus actually lands on $actual. Wrap the flow in '
          'a FocusTraversalGroup with explicit FocusTraversalOrder, or '
          'restructure so the visual order is the focus order.',
    );
  }

  /// Which of [candidates] currently holds focus, directly or by wrapping it.
  Key? _focusedCandidate(List<Key> candidates) {
    final context = FocusManager.instance.primaryFocus?.context;
    // primaryFocus.context is a BuildContext; it is an Element in practice, and
    // a test that cannot locate it is a test that should see null rather than a
    // cast error.
    final focus = context is Element ? context : null;
    if (focus == null) return null;
    for (final key in candidates) {
      final matches = find.byKey(key).evaluate();
      if (matches.isEmpty) continue;
      final target = matches.first;
      if (identical(target, focus)) return key;
      // `Focus` usually wraps the control, but a text field's focus node lives
      // *inside* the field's own subtree, so containment has to be checked in
      // both directions.
      if (_containsElement(target, focus)) return key;
      if (_containsElement(focus, target)) return key;
    }
    return null;
  }

  /// Whether [ancestor]'s subtree contains [target].
  static bool _containsElement(Element ancestor, Element target) {
    if (identical(ancestor, target)) return true;
    var found = false;
    ancestor.visitChildElements((child) {
      if (found) return;
      if (_containsElement(child, target)) found = true;
    });
    return found;
  }

  /// Every activated-by-tap semantics node in the mounted tree.
  ///
  /// The walk stops descending once it reaches an actionable node. Material
  /// builds a button as several nested semantics nodes — the control, then the
  /// label inside it — and the inner ones inherit the tap flag, so descending
  /// reports the *label's* rect (a 32px line of text at 200%) as if it were the
  /// control's, and every sized button looks undersized.
  Iterable<_ActionableNode> _actionableNodes() sync* {
    final root = _rootSemanticsNode();
    if (root == null) return;
    final pending = <SemanticsNode>[root];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      if (node.isInvisible) continue;
      if (_isActionable(node)) {
        yield _ActionableNode(node);
        continue;
      }
      node.visitChildren((child) {
        pending.add(child);
        return true;
      });
    }
  }

  /// The semantics node at the top of the mounted tree.
  ///
  /// Reached by walking up from the first [Scaffold] rather than through
  /// `PipelineOwner.semanticsOwner`, which is deprecated — and which is also
  /// null in a widget test until a frame has been pumped with semantics on, so
  /// it would silently yield "nothing to check" more often than not.
  SemanticsNode? _rootSemanticsNode() {
    final scaffold = find.byType(Scaffold);
    if (scaffold.evaluate().isEmpty) return null;
    RenderObject? render = scaffold.evaluate().first.findRenderObject();
    SemanticsNode? highest;
    while (render != null) {
      final node = render.debugSemantics;
      if (node != null) highest = node;
      render = render.parent;
    }
    return highest;
  }

  static bool _isActionable(SemanticsNode node) =>
      _flags(node).isButton ||
      _flags(node).isTextField ||
      node.getSemanticsData().hasAction(SemanticsAction.tap);

  /// The node's flags, read through the current API.
  ///
  /// `SemanticsData.hasFlag` and `SemanticsData.flags` are both deprecated;
  /// `flagsCollection` is the replacement and is not.
  static SemanticsFlags _flags(SemanticsNode node) =>
      node.getSemanticsData().flagsCollection;

  static bool _isAnnounceable(_ActionableNode node) =>
      node.label.trim().isNotEmpty ||
      node.value.trim().isNotEmpty ||
      node.tooltip.trim().isNotEmpty ||
      _hasLabelledDescendant(node.node);

  static bool _hasLabelledDescendant(SemanticsNode node) {
    var found = false;
    node.visitChildren((child) {
      if (found) return false;
      if (child.label.trim().isNotEmpty ||
          child.tooltip.trim().isNotEmpty ||
          child.value.trim().isNotEmpty ||
          _hasLabelledDescendant(child)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }
}

/// A semantics node the user can activate.
class _ActionableNode {
  _ActionableNode(this.node);

  final SemanticsNode node;

  String get label => node.label;
  String get value => node.value;
  String get tooltip => node.tooltip;
  Rect get rect => node.rect;

  /// Names the node by what a screen reader calls it and where it sits.
  ///
  /// The owning widget is not reachable from a semantics node — `owner` is the
  /// [SemanticsOwner], not the widget — so position and kind are what a person
  /// actually needs to find it on screen.
  String describe(String screen) {
    final flags = node.getSemanticsData().flagsCollection;
    final kind = flags.isTextField
        ? 'text field'
        : flags.isButton
        ? 'button'
        : 'tappable';
    final rect = node.rect;
    return '$screen: a $kind at (${rect.left.toStringAsFixed(0)}, '
        '${rect.top.toStringAsFixed(0)}) ${rect.width.toStringAsFixed(0)}'
        '×${rect.height.toStringAsFixed(0)} with no label';
  }
}

/// Declared accessibility coverage for every component file in
/// `lib/design_system/`.
///
/// A new component file breaks the build until it is added here. `audited()`
/// means the gate file genuinely renders it and runs the checks on it;
/// `deferred(...)` means it is knowingly not audited yet and carries the reason,
/// so the debt stays visible and greppable instead of invisible.
///
/// The gate asserts the file existence of every entry, so a deleted or renamed
/// component cannot leave a permanent phantom entry behind.
const Map<String, AccessibilityCoverage> accessibilityCoverage = {
  'fix_button.dart': AccessibilityCoverage.audited(),
  'fix_card.dart': AccessibilityCoverage.audited(),
  'fix_status_chip.dart': AccessibilityCoverage.audited(),
  'fix_state_views.dart': AccessibilityCoverage.audited(),
  'fix_saved_data_banner.dart': AccessibilityCoverage.audited(),
  'fix_active_booking_island.dart': AccessibilityCoverage.audited(),
  'fix_banner.dart': AccessibilityCoverage.audited(),
  'fix_service_card.dart': AccessibilityCoverage.audited(),
  'fix_page_frame.dart': AccessibilityCoverage.audited(),
  'fix_components.dart': AccessibilityCoverage.audited(),
  'fix_image.dart': AccessibilityCoverage.audited(),
  'fix_address_selector.dart': AccessibilityCoverage.audited(),
  'fix_otp_input_sheet.dart': AccessibilityCoverage.audited(),
  'fix_reschedule_sheet.dart': AccessibilityCoverage.audited(),
  'fix_schedule_picker.dart': AccessibilityCoverage.audited(),
  'fix_rating_badge.dart': AccessibilityCoverage.audited(),
  'fix_price_breakdown_card.dart': AccessibilityCoverage.audited(),
  'fix_notification_bell.dart': AccessibilityCoverage.audited(),
  'fix_bottom_navigation.dart': AccessibilityCoverage.audited(),
  'fix_payment_checkout_sheet.dart': AccessibilityCoverage.audited(),
  'fix_before_after_slider.dart': AccessibilityCoverage.audited(),
  'fix_schedule_hours_sheet.dart': AccessibilityCoverage.audited(),
  'fix_job_proof_dialog.dart': AccessibilityCoverage.deferred(
    'A modal bottom sheet, so it cannot be pumped inline the way the harness '
    'fixtures are. Its upload states are covered by test/job_proof_test.dart, '
    'but the 200% text and 48px target checks have not been run against the '
    'rendered sheet.',
  ),
  'fix_3d_flip_card.dart': AccessibilityCoverage.deferred(
    'Decorative payment-card flip. Its only action opens the payment sheet, '
    'which is itself audited via fix_payment_checkout_sheet.dart.',
  ),
  'fix_accept_celebration.dart': AccessibilityCoverage.deferred(
    'Transient celebration overlay whose information is duplicated by the '
    'booking card it celebrates.',
  ),
  'fix_motion.dart': AccessibilityCoverage.deferred(
    'Motion primitives with no semantics or controls of their own.',
  ),
  'fix_motion_suite.dart': AccessibilityCoverage.deferred(
    'Motion primitives with no semantics or controls of their own.',
  ),
  'signature_motion.dart': AccessibilityCoverage.deferred(
    'Motion primitives. HoldToConfirmButton is reachable only from the '
    'emergency flow, which needs its own audited journey.',
  ),
};

/// How a design-system component file is covered by the accessibility gate.
sealed class AccessibilityCoverage {
  const AccessibilityCoverage();

  /// The gate renders this component and asserts the DESIGN.md §31 checks on
  /// what it actually produces.
  const factory AccessibilityCoverage.audited() = _Audited;

  /// Not audited yet, with the reason written down.
  const factory AccessibilityCoverage.deferred(String reason) = _Deferred;

  bool get isAudited => this is _Audited;

  /// The written reason, or null when audited.
  String? get reason => this is _Deferred ? (this as _Deferred).reason : null;
}

final class _Audited extends AccessibilityCoverage {
  const _Audited();
}

final class _Deferred extends AccessibilityCoverage {
  const _Deferred(this.reason);
  @override
  final String reason;
}

/// Every `.dart` file directly under [rootPath], sorted.
List<String> dartFilesIn(String rootPath) {
  final directory = Directory(rootPath);
  if (!directory.existsSync()) return const [];
  final names =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort();
  return names;
}

/// Design-system files that declare no widget and so need no coverage entry:
/// tokens, motion constants, theme assembly.
const Set<String> designSystemNonComponentFiles = {
  'app_colors.dart',
  'app_motion.dart',
  'app_radius.dart',
  'app_shadows.dart',
  'app_spacing.dart',
  'app_theme.dart',
  'app_typography.dart',
};
