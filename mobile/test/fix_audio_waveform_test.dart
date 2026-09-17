import 'package:fixnow_mobile/design_system/fix_audio_waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FixAudioWaveform renders requested number of frequency bars', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FixAudioWaveform(isSpeaking: true, barCount: 7)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FixAudioWaveform), findsOneWidget);
    // Find containers inside the waveform
    expect(find.byType(AnimatedContainer), findsNWidgets(7));
  });

  testWidgets('FixAudioWaveform handles idle/silence state gracefully', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FixAudioWaveform(isSpeaking: false, barCount: 5)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FixAudioWaveform), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(5));
  });
}
