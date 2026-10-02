// Design-system enforcement gate for the FixNow mobile app.
//
// The audit's finding was not that the tokens were wrong — they are correct and
// they exist in `lib/design_system/`. It was that nothing rejected a literal, so
// 889 inline `fontSize` values, 399 inline radii and 122 text runs below 11px sat
// alongside the token set. DESIGN.md §36 asks for lint rules that make a
// violation a build failure rather than a review comment.
//
// A custom analyzer lint plugin is the idiomatic answer, but it means a new
// dependency on `custom_lint`/`analyzer`, and adding a dependency is a decision
// for the repository owner rather than for a remediation pass. This is the
// dependency-free equivalent: it reads the same source the analyzer would, it
// exits non-zero, and CI runs it.
//
// Usage:
//   dart run tool/check_design_tokens.dart                       # report
//   dart run tool/check_design_tokens.dart --record              # write baseline
//   dart run tool/check_design_tokens.dart --ratchet             # fail on growth
//
// The ratchet matters. With 889 existing font-size literals, a gate that fails
// today is a gate that gets deleted on the first red build. So `--ratchet` fails
// on *regression* — a count above the committed baseline — while printing the
// current numbers, so the debt stays visible and shrinks as it is paid.
//
// Two classes of finding are treated differently on purpose:
//
//  - *accessibility* violations (text under 11pt, a focus ring removed from a
//    text field) are defects. They always fail, baseline or not. Design
//    inconsistency can be ratcheted; unreadable text cannot.
//  - *debt* counters (inline radii, inline spacing) are ratcheted.
import 'dart:io';

/// Text below this is a WCAG 1.4.4 failure for anyone who needs it.
  const accessibilityFloorPt = 11.0;

  /// Text styled to be invisible cannot be too small to read.
  ///
  /// The codebase has one such field by design: a transparent, 1px `TextField`
  /// that backs the visible OTP boxes, so the platform keyboard can drive them
  /// without a second caret appearing on screen. It renders nothing, so a
  /// minimum-size rule applied to it would be a false positive — and a gate with
  /// a demonstrably wrong failure is a gate people disable.
  final _invisibleText = RegExp(
    r'Colors\.transparent|color:\s*Colors\.transparent|opacity:\s*0\b',
  );

final _fontSize = RegExp(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)');
final _radius = RegExp(
  r'BorderRadius\.(?:circular|all)\(\s*([0-9]+(?:\.[0-9]+)?)',
);
final _boxLiteral = RegExp(
  r'\b(?:SizedBox|Container)\(\s*(?:width|height):\s*([0-9]+(?:\.[0-9]+)?)\s*\)',
);
final _borderSideNone = RegExp(r'BorderSide\.none');

class Violation {
  Violation(this.rule, this.file, this.line, this.detail);

  final String rule;
  final String file;
  final int line;
  final String detail;

  @override
  String toString() =>
      '  ${file.split(Platform.pathSeparator).last}:$line  [$rule] $detail';
}

/// The debt counters, and the only thing a baseline records.
class Tally {
  const Tally(
    this.fontSizeLiterals,
    this.fontSizeBelowFloor,
    this.radiusLiterals,
    this.boxLiterals,
    this.borderSideNone,
  );

  final int fontSizeLiterals;
  final int fontSizeBelowFloor;
  final int radiusLiterals;
  final int boxLiterals;
  final int borderSideNone;

  Map<String, int> toMap() => {
        'fontSizeLiterals': fontSizeLiterals,
        'fontSizeBelowFloor': fontSizeBelowFloor,
        'radiusLiterals': radiusLiterals,
        'boxLiterals': boxLiterals,
        'borderSideNone': borderSideNone,
      };

  static Tally fromMap(Map<String, Object?> json) => Tally(
        json['fontSizeLiterals'] as int? ?? 0,
        json['fontSizeBelowFloor'] as int? ?? 0,
        json['radiusLiterals'] as int? ?? 0,
        json['boxLiterals'] as int? ?? 0,
        json['borderSideNone'] as int? ?? 0,
      );

  /// Which counters are worse than the baseline's?
  List<String> regressionsComparedTo(Tally baseline) {
    final mine = toMap();
    final theirs = baseline.toMap();
    return [
      for (final key in mine.keys)
        if (mine[key]! > theirs[key]!) '$key (${theirs[key]} -> ${mine[key]})',
    ];
  }

  String encode() {
    final entries = toMap().entries.map((e) => '"${e.key}":${e.value}').join(',');
    return '{$entries}\n';
  }

  static Tally decode(String source) {
    final result = <String, Object?>{};
    for (final match in RegExp(r'"([A-Za-z]+)":(-?\d+)').allMatches(source)) {
      result[match.group(1)!] = int.parse(match.group(2)!);
    }
    return Tally.fromMap(result);
  }
}

/// Files that legitimately own literals.
///
/// Deliberately narrow: only the *token definition* files, because
/// `app_typography.dart` is where the type scale is defined, and a gate that
/// flagged the definitions would never pass.
///
/// An earlier version exempted the whole `design_system/` directory, which was
/// wrong in a way that mattered: `fix_service_card.dart` and
/// `fix_sos_vortex_button.dart` live there and render to the user, so exempting
/// the directory hid 27 real sub-11pt text runs behind a path that sounded
/// principled. A component is not a token file.
const _tokenDefinitionFiles = {
  'app_typography.dart',
  'app_radius.dart',
  'app_spacing.dart',
  'app_colors.dart',
  'app_motion.dart',
  'app_shadows.dart',
};

bool _isExempt(String relativePath) {
  final normalised = relativePath.replaceAll('\\', '/');
  if (normalised.endsWith('/main.dart')) return true;
  if (normalised.contains('/test/')) return true;
  return _tokenDefinitionFiles.contains(normalised.split('/').last);
}

List<File> _dartFiles(String root) {
  final files = <File>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync()) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        walk(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }

  walk(Directory(root));
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

void main(List<String> args) {
  final root = Directory.current.path;
  final separator = Platform.pathSeparator;
  final libDir = Directory('$root${separator}lib');
  if (!libDir.existsSync()) {
    stderr.writeln('No lib/ directory here. Run this from mobile/.');
    exit(2);
  }

  final record = args.contains('--record');
  final ratchet = args.contains('--ratchet');
  final baselineArg = _valueOf(args, '--baseline');
  final baselinePath =
      baselineArg ?? '$root${separator}tool${separator}design_token_baseline.json';

  var fontSizeLiterals = 0;
  var fontSizeBelowFloor = 0;
  var radiusLiterals = 0;
  var boxLiterals = 0;
  var borderSideNone = 0;
  final accessibility = <Violation>[];

  for (final file in _dartFiles(libDir.path)) {
    final relative = file.path.replaceFirst('$root$separator', '');
    if (_isExempt(relative)) continue;
    final lines = file.readAsLinesSync();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;

      for (final match in _fontSize.allMatches(line)) {
        fontSizeLiterals++;
        final size = double.parse(match.group(1)!);
        if (size >= accessibilityFloorPt) continue;
        if (_invisibleText.hasMatch(line)) continue;
        fontSizeBelowFloor++;
        accessibility.add(
          Violation(
            'type',
            relative,
            i + 1,
            'fontSize $size is below $accessibilityFloorPt; use a '
                'FixNowTypography style',
          ),
        );
      }

      radiusLiterals += _radius.allMatches(line).length;
      boxLiterals += _boxLiteral.allMatches(line).length;
      if (_borderSideNone.hasMatch(line)) {
        borderSideNone++;
        // A text field with `BorderSide.none` has no focus ring at all, which is
        // what MOB-006 found on the sign-in form — the most important form in
        // the product.
        if (line.contains('TextField') || line.contains('TextFormField')) {
          accessibility.add(
            Violation(
              'focus',
              relative,
              i + 1,
              'BorderSide.none on a text field removes the focus indicator',
            ),
          );
        }
      }
    }
  }

  final tally = Tally(
    fontSizeLiterals,
    fontSizeBelowFloor,
    radiusLiterals,
    boxLiterals,
    borderSideNone,
  );

  stdout
    ..writeln('Design-system gate')
    ..writeln('  inline font-size literals ........ $fontSizeLiterals'
        '   (tokens: lib/design_system/app_typography.dart)')
    ..writeln('  of those below ${accessibilityFloorPt}pt ........ '
        '$fontSizeBelowFloor   (accessibility defect)')
    ..writeln('  inline BorderRadius literals ..... $radiusLiterals'
        '   (tokens: lib/design_system/app_radius.dart)')
    ..writeln('  inline box literals .............. $boxLiterals'
        '   (tokens: lib/design_system/app_spacing.dart)')
    ..writeln('  BorderSide.none .................. $borderSideNone')
    ..writeln('');

  if (record) {
    File(baselinePath)
      ..createSync(recursive: true)
      ..writeAsStringSync(tally.encode());
    stdout.writeln('Recorded baseline to $baselinePath');
    return;
  }

  // Accessibility first, and independently of the ratchet: a text size that
  // makes something unreadable is a defect, not debt.
  if (accessibility.isNotEmpty) {
    stderr.writeln('FAIL: ${accessibility.length} accessibility violation(s). '
        'These are defects, not debt, so the baseline does not excuse them:');
    for (final violation in accessibility.take(40)) {
      stderr.writeln(violation.toString());
    }
    if (accessibility.length > 40) {
      stderr.writeln('  ... and ${accessibility.length - 40} more');
    }
    stderr.writeln('');
    exit(1);
  }
  stdout.writeln('No accessibility violations: nothing below '
      '${accessibilityFloorPt}pt, no focus ring removed.');

  if (ratchet) {
    if (!File(baselinePath).existsSync()) {
      stderr.writeln('No baseline at $baselinePath. '
          'Run once with --record to establish one.');
      exit(1);
    }
    final baseline = Tally.decode(File(baselinePath).readAsStringSync());
    final regressions = tally.regressionsComparedTo(baseline);
    if (regressions.isEmpty) {
      stdout.writeln('No regression against the recorded baseline.');
      return;
    }
    stderr.writeln('FAIL: the design-system debt grew.');
    for (final regression in regressions) {
      stderr.writeln('  $regression');
    }
    stderr.writeln('');
    stderr.writeln('Use a token from lib/design_system/ rather than a '
        'literal. See DESIGN.md §36. If the debt really did shrink, re-record '
        'with --record; if it grew, that is the gate working.');
    exit(1);
  }
}

String? _valueOf(List<String> args, String flag) {
  final index = args.indexOf(flag);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}