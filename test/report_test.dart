import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_a11y_check/flutter_a11y_check.dart';
import 'package:flutter_test/flutter_test.dart';

const A11yFinding tap = A11yFinding(
  rule: A11yRule.tapTarget,
  severity: A11ySeverity.error,
  message: 'IconButton is 32x32, smaller than the 48x48 minimum tap target.',
  suggestion: 'Wrap it in SizedBox.square(dimension: 48).',
  widget: 'IconButton',
  path: 'LoginScreen > Scaffold > AppBar > IconButton',
  rect: Rect.fromLTWH(8, 12.04, 32, 32),
  variant: '100%',
  data: <String, Object?>{'width': 32.0},
);

const A11yFinding image = A11yFinding(
  rule: A11yRule.imageLabel,
  severity: A11ySeverity.warning,
  message: 'Image has no semanticLabel | pipe',
  suggestion: 'Add semanticLabel.',
);

const A11yFinding order = A11yFinding(
  rule: A11yRule.focusOrder,
  severity: A11ySeverity.info,
  message: 'Order jumps.',
  suggestion: 'Check it.',
);

void main() {
  const A11yReport report = A11yReport(
    findings: <A11yFinding>[tap, image, order],
    variants: <String>['100%', '200%'],
    ignored: 2,
    notes: <String>['a note'],
  );

  test('counts and pass/fail by threshold', () {
    expect(report.errors, <A11yFinding>[tap]);
    expect(report.warnings, <A11yFinding>[image]);
    expect(report.infos, <A11yFinding>[order]);
    expect(report.passed, isFalse);
    expect(
      const A11yReport(findings: <A11yFinding>[image], failOn: A11ySeverity.error).passed,
      isTrue,
    );
    expect(const A11yReport(findings: <A11yFinding>[order]).passed, isTrue);
    expect(
      const A11yReport(findings: <A11yFinding>[order], failOn: A11ySeverity.info).passed,
      isFalse,
    );
  });

  test('toText without color', () {
    final String text = report.toText(color: false);
    expect(text, isNot(contains('\x1B[')));
    expect(text, startsWith('Accessibility audit FAILED: 1 error, 1 warning, 1 info'));
    expect(text, contains('runs: 100%, 200% | 2 ignored'));
    expect(text, contains('ERROR  tap-target  IconButton is 32x32'));
    expect(text, contains('where LoginScreen > Scaffold > AppBar > IconButton'));
    expect(text, contains('rect  (8, 12) 32x32 at 100%'));
    expect(text, contains('fix   Wrap it in SizedBox.square(dimension: 48).'));
    expect(text, contains('note   a note'));
    expect(report.toString(), text);
  });

  test('toText with color uses ANSI codes', () {
    final String text = report.toText();
    expect(text, contains('\x1B[1;31mFAILED\x1B[0m'));
    expect(text, contains('\x1B[1;33mWARN   \x1B[0m'));
  });

  test('toMarkdown renders a table and escapes pipes', () {
    final String md = report.toMarkdown();
    expect(md, startsWith('## Accessibility audit: failed'));
    expect(md, contains('| Severity | Rule | Where | Issue | Fix |'));
    expect(
      md,
      contains('| 🔴 error | `tap-target` | `LoginScreen > Scaffold > AppBar > IconButton`'),
    );
    expect(md, contains(r'semanticLabel \| pipe'));
    expect(md, contains('> a note'));
    expect(
      const A11yReport(findings: <A11yFinding>[]).toMarkdown(),
      contains('No accessibility issues found.'),
    );
  });

  test('toJson is valid JSON with rounded rects and rule ids', () {
    final Map<String, Object?> json = jsonDecode(report.toJsonString()) as Map<String, Object?>;
    expect(json['passed'], isFalse);
    expect(json['summary'], <String, Object?>{'error': 1, 'warning': 1, 'info': 1, 'ignored': 2});
    final List<Object?> findings = json['findings']! as List<Object?>;
    final Map<String, Object?> first = findings.first! as Map<String, Object?>;
    expect(first['rule'], 'tap-target');
    expect(first['rect'], <String, Object?>{
      'left': 8.0,
      'top': 12.0,
      'width': 32.0,
      'height': 32.0,
    });
    expect((findings[1]! as Map<String, Object?>).containsKey('rect'), isFalse);
  });

  test('rule ids round-trip and severities order', () {
    for (final A11yRule rule in A11yRule.values) {
      expect(A11yRule.byId(rule.id), rule);
    }
    expect(A11yRule.byId('nope'), isNull);
    expect(A11ySeverity.error.isAtLeast(A11ySeverity.warning), isTrue);
    expect(A11ySeverity.info.isAtLeast(A11ySeverity.warning), isFalse);
    expect(A11yRule.defaults, isNot(contains(A11yRule.focusOrder)));
  });
}
