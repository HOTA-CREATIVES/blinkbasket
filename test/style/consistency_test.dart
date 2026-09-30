import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Cheap source-level guards for conventions that had drifted: one spelling of
/// the brand, one money format, one date format, no raw exception text in UI.
/// They read the app's own source, so a violation names the file and line.
List<File> _dartFiles({bool includeAdmin = true}) => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => includeAdmin || !f.path.contains('${Platform.pathSeparator}admin${Platform.pathSeparator}'))
    .toList();

List<String> _violations(RegExp pattern, {bool includeAdmin = true, bool Function(String path)? skip}) {
  final found = <String>[];
  for (final file in _dartFiles(includeAdmin: includeAdmin)) {
    if (skip != null && skip(file.path)) continue;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      if (pattern.hasMatch(line)) found.add('${file.path}:${i + 1}: ${line.trim()}');
    }
  }
  return found;
}

void main() {
  test('the brand is spelled "J C Mart" everywhere (never "JC Mart")', () {
    expect(_violations(RegExp(r'\bJC Mart\b')), isEmpty);
  });

  test('customer and rider screens format money with formatRupees, not by hand', () {
    expect(
      _violations(
        RegExp(r'₹\$\{[^}]*toStringAsFixed'),
        includeAdmin: false,
        skip: (p) => p.endsWith('money.dart'),
      ),
      isEmpty,
    );
  });

  test('dates and times use the shared formatters, not hand-rolled d/m/y strings', () {
    expect(
      _violations(
        RegExp(r"\.day\}\s*/|\.hour % 12"),
        includeAdmin: false,
        skip: (p) => p.endsWith('date_format.dart'),
      ),
      isEmpty,
    );
  });

  test('no screen or provider pastes a raw exception into user-facing text', () {
    // `$e` / `${e}` / e.toString() inside a string shown to people. Repositories
    // and providers turn errors into messages with userMessageFor instead.
    final violations = _violations(
      RegExp(r"(Text|SnackBar|_showSnackBar|_snack|_errorMessage\s*=).*(\$e\b|\$\{e\}|\$error\b|(?<![A-Za-z0-9_])e\.toString\(\))"),
      skip: (p) => p.contains('debug') || p.endsWith('app_exception.dart'),
    );
    expect(violations, isEmpty);
  });
}
