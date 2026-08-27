import 'package:flutter_test/flutter_test.dart';

/// Test-suite helpers for the motion-enabled design system.
extension PumpIdle on WidgetTester {
  /// Declares reduce-motion for this test (exactly what an
  /// accessibility-conscious user would set), flushes in-flight futures
  /// (repository loads, timers), and settles the widget tree.
  ///
  /// The design system's ambient motion (FixPulse, shimmer sweeps) repeats
  /// forever by design, so `pumpAndSettle` alone can never complete while a
  /// skeleton is visible. With reduce-motion those tickers stay idle. The
  /// leading `pump` gives asynchronous loads their event-loop turn, which
  /// the looping skeletons used to do by accident.
  ///
  /// Scoped to [WidgetTester] — not a global test config — so pure-Dart test
  /// files are never dragged into the widget binding.
  Future<void> pumpIdle() async {
    platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    await pump();
    await pumpAndSettle();
  }
}
