// Bisects the sub-11pt font bump against a widget test, to find which file's
// change causes a layout overflow.
//
// This exists because the accessibility fix surfaced real layout fragility: a
// `Row` sized to fit at 9-10pt overflows once the text is readable, and a 126-site
// diff is a poor place to look for it.
//
// Two correctness rules the earlier attempt got wrong, both of which produced a
// confident wrong answer:
//
//  1. It must shell out through `cmd.exe` on Windows — `flutter` is a `.bat` and
//     `Process.runSync` cannot execute one directly.
//  2. It must restore each file after a passing iteration, so the tree ends at
//     "clean plus one file". Otherwise a file whose *combined* effect fails is
//     blamed individually, which is how an unmounted widget got reported as the
//     culprit.
//
// Usage: dart run tool/bisect_font_bump.dart --test test/app_test.dart
import 'dart:convert';
import 'dart:io';

final skip = <String>{
  'app_typography.dart',
  'app_radius.dart',
  'app_spacing.dart',
  'app_colors.dart',
  'app_motion.dart',
  'app_shadows.dart',
  'main.dart',
};

final pattern = RegExp(r'fontSize:\s*(8|9|10)(\.[0-9])?\b');

String? argOf(List<String> args, String flag) {
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == flag) return args[i + 1];
  }
  return null;
}

bool testFails(List<String> flutterArgs) {
  final result = Process.runSync(
    'cmd.exe',
    ['/c', 'flutter', ...flutterArgs],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return '${result.stdout}${result.stderr}'.contains('Some tests failed');
}

void main(List<String> args) {
  final testFile = argOf(args, '--test') ?? 'test/app_test.dart';
  final plainName = argOf(args, '--name') ?? 'supports narrow screens';

  final candidates = <File>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (skip.contains(entity.path.split(Platform.pathSeparator).last)) {
      continue;
    }
    if (pattern.hasMatch(entity.readAsStringSync(encoding: utf8))) {
      candidates.add(entity);
    }
  }

  stdout.writeln('Bisecting ${candidates.length} files against '
      '$testFile --plain-name "$plainName"');

  final baselineFails = testFails([
    'test',
    testFile,
    '--plain-name',
    plainName,
  ]);
  if (baselineFails) {
    stderr.writeln('The test already fails on a clean tree, so nothing can be '
        'attributed to the bump. Stopping.');
    exit(1);
  }

  for (final file in candidates) {
    final original = file.readAsStringSync(encoding: utf8);
    file.writeAsStringSync(
      original.replaceAll(pattern, 'fontSize: 11'),
      encoding: utf8,
    );
    final broke = testFails([
      'test',
      testFile,
      '--plain-name',
      plainName,
    ]);
    if (broke) {
      stdout.writeln('CULPRIT: ${file.path}');
      stdout.writeln('Left applied so the overflow can be inspected.');
      return;
    }
    file.writeAsStringSync(original, encoding: utf8);
    stdout.writeln('  ok  ${file.path}');
  }

  stdout.writeln('No single file causes the failure. The remaining suspects:');
  for (final file in candidates) {
    stdout.writeln('  ${file.path}');
  }
}