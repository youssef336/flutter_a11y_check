import 'package:flutter/material.dart';
import 'package:flutter_a11y_check/flutter_a11y_check.dart';
import 'package:flutter_a11y_check_example/main.dart';
import 'package:flutter_a11y_check_example/screens/bad_screen.dart';
import 'package:flutter_a11y_check_example/screens/good_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const A11yConfig everything = A11yConfig(rules: <A11yRule>{...A11yRule.values}, rtl: true);

void main() {
  group('bad screen', () {
    late A11yReport report;

    Future<void> audit(WidgetTester tester) async {
      await tester.pumpWidget(const ExampleApp(home: BadScreen()));
      report = await auditAccessibility(tester, config: everything);
    }

    List<A11yFinding> of(A11yRule rule) => report.byRule(rule);

    testWidgets('tap-target: shrink-wrapped TextButton and 24x24 GestureDetector', (
      WidgetTester tester,
    ) async {
      await audit(tester);
      final List<String?> widgets = of(
        A11yRule.tapTarget,
      ).map((A11yFinding f) => f.widget).toList();
      expect(widgets, containsAll(<String>['TextButton', 'GestureDetector']));
      final A11yFinding skip = of(
        A11yRule.tapTarget,
      ).firstWhere((A11yFinding f) => f.widget == 'TextButton');
      expect(skip.label, 'Skip');
      expect(skip.path, 'BadScreen > Scaffold > ListView > Row > TextButton');
      expect(skip.rect!.height, 24);
      expect(skip.severity, A11ySeverity.error);
    });

    testWidgets('missing-label: IconButton without tooltip and bare GestureDetector', (
      WidgetTester tester,
    ) async {
      await audit(tester);
      final List<A11yFinding> found = of(A11yRule.missingLabel);
      expect(
        found.map((A11yFinding f) => f.widget),
        containsAll(<String>['IconButton', 'GestureDetector']),
      );
      expect(
        found.firstWhere((A11yFinding f) => f.widget == 'IconButton').path,
        'BadScreen > Scaffold > AppBar > Row > IconButton',
      );
      expect(found.first.suggestion, isNotEmpty);
    });

    testWidgets('contrast: light grey text, with measured colors', (WidgetTester tester) async {
      await audit(tester);
      final A11yFinding f = of(A11yRule.contrast).single;
      expect(f.label, 'Prices include VAT');
      expect(f.data['foreground'], '#BDBDBD');
      expect(f.data['ratio'] as double, lessThan(4.5));
      expect(f.data['required'], 4.5);
      expect(f.data['suggestedForeground'], isA<String>());
    });

    testWidgets('image-label: Image without semanticLabel', (WidgetTester tester) async {
      await audit(tester);
      final A11yFinding f = of(A11yRule.imageLabel).single;
      expect(f.widget, 'Image');
      expect(f.severity, A11ySeverity.warning);
    });

    testWidgets('text-scale: overflow, truncation and fixed-size text at 200%', (
      WidgetTester tester,
    ) async {
      await audit(tester);
      final List<A11yFinding> found = of(A11yRule.textScale);
      expect(found.any((A11yFinding f) => f.widget == 'Row' && f.message.contains('200%')), isTrue);
      expect(found.any((A11yFinding f) => f.message.contains('gets cut off')), isTrue);
      expect(found.any((A11yFinding f) => f.message.contains('Build 1.0.3')), isTrue);
    });

    testWidgets('duplicate-label and generic-label', (WidgetTester tester) async {
      await audit(tester);
      final A11yFinding dup = of(A11yRule.duplicateLabel).single;
      expect(dup.label, 'Remove');
      expect(dup.data['count'], 3);
      expect(of(A11yRule.genericLabel).single.label, 'Click here');
    });

    testWidgets('focus-order: sort keys read "Click here" before "Back"', (
      WidgetTester tester,
    ) async {
      await audit(tester);
      final A11yFinding f = of(A11yRule.focusOrder).single;
      expect(f.severity, A11ySeverity.info);
      expect(f.label, 'Back');
    });

    testWidgets('expectAccessible fails with the full report', (WidgetTester tester) async {
      await tester.pumpWidget(const ExampleApp(home: BadScreen()));
      Object? error;
      try {
        await expectAccessible(tester, config: const A11yConfig(colors: false));
      } on TestFailure catch (e) {
        error = e;
      }
      expect(error, isA<TestFailure>());
      final String message = error.toString();
      expect(message, contains('Accessibility audit FAILED'));
      expect(message, contains('tap-target'));
      expect(message, contains('fix'));
    });

    testWidgets('restores text scale and locale afterwards', (WidgetTester tester) async {
      await audit(tester);
      expect(tester.platformDispatcher.textScaleFactor, 1.0);
      final BuildContext context = tester.element(find.byType(BadScreen));
      expect(Directionality.of(context), TextDirection.ltr);
      expect(MediaQuery.textScalerOf(context).scale(10), 10);
    });
  });

  group('good screen', () {
    testWidgets('passes every rule at 100% and 200%, LTR and RTL', (WidgetTester tester) async {
      await tester.pumpWidget(const ExampleApp(home: GoodScreen()));
      final A11yReport report = await expectAccessible(
        tester,
        config: everything.copyWithFailOnInfo(),
      );
      expect(report.findings, isEmpty);
      expect(report.variants, <String>['100%', '200%', '100% ar (rtl)', '200% ar (rtl)']);
      expect(report.notes, isEmpty);
    });

    testWidgets('picker screen passes too', (WidgetTester tester) async {
      await tester.pumpWidget(const ExampleApp());
      await expectAccessible(tester);
    });
  });

  testWidgets('RTL run is skipped with a note when the app has no RTL locale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GoodScreen()));
    final A11yReport report = await auditAccessibility(tester, config: const A11yConfig(rtl: true));
    expect(report.variants, <String>['100%', '200%']);
    expect(report.notes.single, contains('stayed left-to-right'));
  });
}

extension on A11yConfig {
  A11yConfig copyWithFailOnInfo() => A11yConfig(rules: rules, rtl: rtl, failOn: A11ySeverity.info);
}
