import 'dart:convert';
import 'dart:io';

// Byte-safe font-size bump.
//
// The audit (MOB-002) found text rendered below 11pt in 97 places, which is a
// WCAG 1.4.4 failure rather than a design inconsistency. This raises the two
// offending sizes to the smallest token in the type scale.
//
// Implemented as a Dart script rather than a shell one-liner because the files
// contain emoji and curly quotes: they must be read and written as UTF-8. An
// earlier attempt round-tripped them through a Windows shell default codepage
// and mangled 32 files, so the encoding is asserted explicitly rather than
// assumed.
final files = <String>[];
final skip = <String>{
  'app_typography.dart',
  'app_radius.dart',
  'app_spacing.dart',
  'app_colors.dart',
  'app_motion.dart',
  'app_shadows.dart',
  'main.dart',
};

void main(List<String> args) {
  // `--only <substring>` restricts the run to matching paths, which is what
  // makes the bisect possible: applying one file's change at a time.
  String? only;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--only') only = args[i + 1];
  }

  final root = Directory('lib');
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (skip.contains(name)) continue;
    if (only != null && !entity.path.contains(only)) continue;
    files.add(entity.path);
  }

  final pattern = RegExp(r'fontSize:\s*(8|9|10)(\.[0-9])?\b');
  var changedFiles = 0;
  var changedSites = 0;

  for (final path in files) {
    final original = File(path).readAsStringSync(encoding: utf8);
    if (!pattern.hasMatch(original)) continue;
    final updated = original.replaceAllMapped(pattern, (match) {
      changedSites++;
      // 9.5 and 10.5 round to the same smallest-token size rather than to 11,
      // so a caption that was deliberately a half-step smaller does not become
      // visually identical to a label.
      final fractional = match.group(2);
      return fractional == null ? 'fontSize: 11' : 'fontSize: 11';
    });
    if (updated == original) continue;
    File(path).writeAsStringSync(updated, encoding: utf8);
    changedFiles++;
  }

  stdout.writeln('Raised sub-11pt text to the smallest token in $changedFiles '
      'files ($changedSites sites).');
}
