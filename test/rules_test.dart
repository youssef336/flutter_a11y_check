import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_a11y_check/flutter_a11y_check.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget body) => MaterialApp(
  home: Scaffold(body: Center(child: body)),
);

void main() {
  testWidgets('tap target threshold follows minTapTarget (Android 48 vs iOS 44)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        SizedBox.square(
          dimension: 46,
          child: Semantics(
            container: true,
            button: true,
            label: 'Play',
            child: GestureDetector(onTap: () {}),
          ),
        ),
      ),
    );
    const A11yConfig android = A11yConfig(textScales: <double>[1.0]);
    const A11yConfig ios = A11yConfig(
      textScales: <double>[1.0],
      minTapTarget: A11yConfig.iosTapTarget,
    );
    final A11yFinding f = (await auditAccessibility(
      tester,
      config: android,
    )).byRule(A11yRule.tapTarget).single;
    expect(f.message, contains('46x46'));
    expect(f.data['min'], 48);
    expect((await auditAccessibility(tester, config: ios)).findings, isEmpty);
  });

  testWidgets('contrast level AA vs AAA and off', (WidgetTester tester) async {
    // #767676 on white is 4.54:1: passes AA, fails AAA.
    await tester.pumpWidget(
      app(
        const ColoredBox(
          color: Color(0xFFFFFFFF),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Text('Grey', style: TextStyle(color: Color(0xFF767676), fontSize: 14)),
          ),
        ),
      ),
    );
    Future<A11yReport> run(ContrastLevel level) => auditAccessibility(
      tester,
      config: A11yConfig(textScales: const <double>[1.0], contrast: level),
    );
    expect((await run(ContrastLevel.aa)).byRule(A11yRule.contrast), isEmpty);
    final A11yFinding aaa = (await run(ContrastLevel.aaa)).byRule(A11yRule.contrast).single;
    expect(aaa.data['required'], 7);
    expect(aaa.data['background'], '#FFFFFF');
    expect(aaa.data['foreground'], '#767676');
    expect(aaa.message, contains('WCAG AAA'));
    expect((await run(ContrastLevel.off)).byRule(A11yRule.contrast), isEmpty);
  });

  testWidgets('decorative and labelled images are fine', (WidgetTester tester) async {
    final MemoryImage provider = MemoryImage(kTransparentPng);
    await tester.pumpWidget(
      app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image(image: provider, width: 10, height: 10, excludeFromSemantics: true),
            Image(image: provider, width: 10, height: 10, semanticLabel: 'Logo'),
            ExcludeSemantics(child: Image(image: provider, width: 10, height: 10)),
            Image(key: const Key('bad'), image: provider, width: 10, height: 10),
          ],
        ),
      ),
    );
    final A11yReport report = await auditAccessibility(
      tester,
      config: const A11yConfig(textScales: <double>[1.0]),
    );
    final A11yFinding f = report.byRule(A11yRule.imageLabel).single;
    expect(f.element!.widget.key, const Key('bad'));
  });

  testWidgets('clamped text scaling is not reported, pinned scaling is', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (BuildContext context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Clamped',
                textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
              ),
              const Text('Pinned', textScaler: TextScaler.noScaling),
            ],
          ),
        ),
      ),
    );
    final A11yFinding f = (await auditAccessibility(tester)).byRule(A11yRule.textScale).single;
    expect(f.label, 'Pinned');
    expect(f.severity, A11ySeverity.warning);
  });

  Widget twoButtons() => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      TextButton(onPressed: () {}, child: const Text('First')),
      TextButton(onPressed: () {}, child: const Text('Second')),
    ],
  );

  const A11yConfig focusOnly = A11yConfig(
    textScales: <double>[1.0],
    rules: <A11yRule>{A11yRule.focusOrder},
  );

  testWidgets('RTL focus order: an Arabic app reading right to left is fine', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const <Locale>[Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: Center(child: twoButtons())),
      ),
    );
    expect((await auditAccessibility(tester, config: focusOnly)).findings, isEmpty);
  });

  testWidgets('RTL focus order: a nested RTL row still read left to right is flagged', (
    WidgetTester tester,
  ) async {
    // The row is laid out RTL, but the surrounding semantics are LTR, so a screen reader visits
    // "Second" (on the left) before "First" (on the right).
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: twoButtons())),
        ),
      ),
    );
    final A11yFinding f = (await auditAccessibility(
      tester,
      config: focusOnly,
    )).byRule(A11yRule.focusOrder).single;
    expect(f.label, 'First');
    expect(f.message, contains('back to the right'));
  });
}

/// 1x1 transparent PNG.
final Uint8List kTransparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, //
  0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, //
  0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, //
  0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
