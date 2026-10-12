import 'package:flutter/material.dart';
import 'package:flutter_a11y_check/flutter_a11y_check.dart';
import 'package:flutter_test/flutter_test.dart';

Widget screen() => MaterialApp(
  home: Scaffold(
    body: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(key: const Key('share'), icon: const Icon(Icons.share), onPressed: () {}),
          IconButton(icon: const Icon(Icons.close), onPressed: () {}),
          TextButton(onPressed: () {}, child: const Text('Remove')),
          TextButton(onPressed: () {}, child: const Text('Remove')),
        ],
      ),
    ),
  ),
);

const A11yConfig base = A11yConfig(textScales: <double>[1.0]);

void main() {
  test('label ignore matches the exact label and respects rule limits', () {
    const A11yFinding f = A11yFinding(
      rule: A11yRule.duplicateLabel,
      severity: A11ySeverity.warning,
      message: 'm',
      suggestion: 's',
      label: 'Remove',
    );
    expect(const A11yIgnore.label('Remove').appliesTo(f), isTrue);
    expect(const A11yIgnore.label('Delete').appliesTo(f), isFalse);
    expect(
      const A11yIgnore.label('Remove', rules: <A11yRule>{A11yRule.contrast}).appliesTo(f),
      isFalse,
    );
    expect(A11yIgnore.rule(A11yRule.duplicateLabel).appliesTo(f), isTrue);
    expect(A11yIgnore.rule(A11yRule.contrast).appliesTo(f), isFalse);
    // A finder ignore never matches a finding without an element.
    expect(A11yIgnore.finder(find.byType(Text)).appliesTo(f), isFalse);
  });

  testWidgets('baseline: two unlabelled icon buttons and a duplicate', (WidgetTester tester) async {
    await tester.pumpWidget(screen());
    final A11yReport report = await auditAccessibility(tester, config: base);
    expect(report.byRule(A11yRule.missingLabel), hasLength(2));
    expect(report.byRule(A11yRule.duplicateLabel), hasLength(1));
    expect(report.ignored, 0);
  });

  testWidgets('key ignore covers the widget and its descendants', (WidgetTester tester) async {
    await tester.pumpWidget(screen());
    final A11yReport report = await auditAccessibility(
      tester,
      config: A11yConfig(
        textScales: const <double>[1.0],
        ignore: <A11yIgnore>[A11yIgnore.key(const Key('share'))],
      ),
    );
    expect(report.byRule(A11yRule.missingLabel), hasLength(1));
    expect(report.ignored, 1);
  });

  testWidgets('finder ignore limited to one rule', (WidgetTester tester) async {
    await tester.pumpWidget(screen());
    final A11yReport report = await auditAccessibility(
      tester,
      config: A11yConfig(
        textScales: const <double>[1.0],
        ignore: <A11yIgnore>[
          A11yIgnore.finder(find.byType(IconButton), rules: <A11yRule>{A11yRule.missingLabel}),
        ],
      ),
    );
    expect(report.byRule(A11yRule.missingLabel), isEmpty);
    expect(report.byRule(A11yRule.duplicateLabel), hasLength(1));
    expect(report.ignored, 2);
  });

  testWidgets('ignoreRules, rules and severityOverrides', (WidgetTester tester) async {
    await tester.pumpWidget(screen());
    final A11yReport report = await auditAccessibility(
      tester,
      config: const A11yConfig(
        textScales: <double>[1.0],
        ignoreRules: <A11yRule>{A11yRule.missingLabel},
        severityOverrides: <A11yRule, A11ySeverity>{A11yRule.duplicateLabel: A11ySeverity.info},
      ),
    );
    expect(report.byRule(A11yRule.missingLabel), isEmpty);
    expect(report.byRule(A11yRule.duplicateLabel).single.severity, A11ySeverity.info);
    expect(report.passed, isTrue);
  });

  testWidgets('expectAccessible passes once everything is ignored', (WidgetTester tester) async {
    await tester.pumpWidget(screen());
    await expectAccessible(
      tester,
      config: A11yConfig(
        textScales: const <double>[1.0],
        ignore: <A11yIgnore>[
          A11yIgnore.rule(A11yRule.missingLabel),
          const A11yIgnore.label('remove', reason: 'case-sensitive, so this does not match'),
          const A11yIgnore.label('Remove'),
        ],
      ),
    );
  });
}
