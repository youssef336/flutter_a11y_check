import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'config.dart';
import 'context.dart';
import 'finding.dart';
import 'ignore.dart';
import 'report.dart';
import 'rules/contrast_rule.dart';
import 'rules/focus_order.dart';
import 'rules/images.dart';
import 'rules/labels.dart';
import 'rules/tap_target.dart';
import 'rules/text_scale.dart';

/// Audits the screen currently pumped in [tester] and returns every finding.
///
/// The audit runs once per text scale in [A11yConfig.textScales] (1.0 always included) and per
/// extra locale ([A11yConfig.locales], [A11yConfig.rtl]). The same problem seen in several runs is
/// reported once, tagged with the first run that hit it. The tester's text scale and locales are
/// restored afterwards.
///
/// ```dart
/// final report = await auditAccessibility(tester);
/// debugPrint(report.toMarkdown());
/// ```
Future<A11yReport> auditAccessibility(
  WidgetTester tester, {
  A11yConfig config = const A11yConfig(),
}) async {
  final SemanticsHandle handle = tester.ensureSemantics();
  final TestPlatformDispatcher dispatcher = tester.platformDispatcher;
  final double priorScale = dispatcher.textScaleFactor;
  final List<Locale> priorLocales = List<Locale>.of(dispatcher.locales);

  final Map<String, A11yFinding> merged = <String, A11yFinding>{};
  final Set<String> ignoredKeys = <String>{};
  final List<String> variants = <String>[];
  final List<String> notes = <String>[];

  try {
    for (final Locale? locale in <Locale?>[null, ...config.effectiveLocales]) {
      if (locale != null) {
        dispatcher.localesTestValue = <Locale>[locale];
      }
      Set<Element> baseline = <Element>{};
      for (final double scale in config.effectiveTextScales) {
        dispatcher.textScaleFactorTestValue = scale;
        final List<FlutterErrorDetails> errors = await _settleCollectingOverflows(tester);
        final String label = _variantLabel(scale, locale);
        final AuditContext ctx = AuditContext(tester: tester, config: config, variant: label)
          ..textScale = scale;
        ctx.layoutErrors.addAll(errors);
        if (locale != null &&
            A11yConfig.isRtlLocale(locale) &&
            ctx.textDirection != TextDirection.rtl) {
          notes.add(
            'The ${locale.toLanguageTag()} run was skipped: the app stayed left-to-right. Add '
            "Locale('${locale.languageCode}') to supportedLocales (with "
            'GlobalMaterialLocalizations.delegate) to audit the RTL layout.',
          );
          break;
        }
        if (scale == 1.0) {
          baseline = truncatedTexts();
        }
        ctx.baselineTruncated = baseline;
        variants.add(label);

        for (final A11yFinding finding in await _runRules(ctx)) {
          final String key = finding.dedupeKey ?? '${finding.rule.id}|${finding.message}';
          if (merged.containsKey(key) || ignoredKeys.contains(key)) {
            continue;
          }
          if (config.ignore.any((A11yIgnore i) => i.appliesTo(finding))) {
            ignoredKeys.add(key);
            continue;
          }
          merged[key] = finding;
        }
      }
    }
  } finally {
    dispatcher.clearTextScaleFactorTestValue();
    if (dispatcher.textScaleFactor != priorScale) {
      dispatcher.textScaleFactorTestValue = priorScale;
    }
    dispatcher.clearLocalesTestValue();
    if (!listEquals(dispatcher.locales, priorLocales)) {
      dispatcher.localesTestValue = priorLocales;
    }
    await _settleCollectingOverflows(tester);
    handle.dispose();
  }

  final List<A11yFinding> findings = merged.values.toList();
  mergeSort<A11yFinding>(
    findings,
    compare: (A11yFinding a, A11yFinding b) {
      final int bySeverity = b.severity.index.compareTo(a.severity.index);
      if (bySeverity != 0) {
        return bySeverity;
      }
      return a.rule.index.compareTo(b.rule.index);
    },
  );
  return A11yReport(
    findings: findings,
    variants: variants,
    ignored: ignoredKeys.length,
    notes: notes,
    failOn: config.failOn,
  );
}

/// Audits the current screen and fails the test with a full report if any finding reaches
/// [A11yConfig.failOn] (warnings and errors by default).
///
/// ```dart
/// testWidgets('login is accessible', (tester) async {
///   await tester.pumpWidget(const MyApp());
///   await expectAccessible(tester);
/// });
/// ```
Future<A11yReport> expectAccessible(
  WidgetTester tester, {
  A11yConfig config = const A11yConfig(),
  String? reason,
}) async {
  final A11yReport report = await auditAccessibility(tester, config: config);
  if (!report.passed) {
    final String header = reason == null ? '' : '$reason\n\n';
    fail('$header${report.toText(color: config.colors)}');
  }
  return report;
}

Future<List<A11yFinding>> _runRules(AuditContext ctx) async {
  final A11yConfig config = ctx.config;
  return <A11yFinding>[
    if (config.runs(A11yRule.tapTarget)) ...checkTapTargets(ctx),
    if (config.runs(A11yRule.missingLabel)) ...checkMissingLabels(ctx),
    if (config.runs(A11yRule.duplicateLabel) || config.runs(A11yRule.genericLabel))
      ...checkDuplicateAndGenericLabels(ctx),
    if (config.runs(A11yRule.contrast)) ...await checkContrast(ctx),
    if (config.runs(A11yRule.imageLabel)) ...checkImages(ctx),
    if (config.runs(A11yRule.textScale)) ...checkTextScale(ctx),
    if (config.runs(A11yRule.focusOrder)) ...checkFocusOrder(ctx),
  ];
}

String _variantLabel(double scale, Locale? locale) {
  final String percent = '${(scale * 100).round()}%';
  if (locale == null) {
    return percent;
  }
  final String rtl = A11yConfig.isRtlLocale(locale) ? ' (rtl)' : '';
  return '$percent ${locale.toLanguageTag()}$rtl';
}

/// Pumps until the screen settles (or 2s of fake time pass), collecting layout overflow errors
/// instead of letting them fail the test. Any other error goes to the test as usual.
Future<List<FlutterErrorDetails>> _settleCollectingOverflows(WidgetTester tester) async {
  final List<FlutterErrorDetails> overflows = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (isOverflowError(details)) {
      overflows.add(details);
    } else {
      original?.call(details);
    }
  };
  try {
    await tester.pump();
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
    } on FlutterError {
      // Endless animation (e.g. a progress indicator): one more frame is enough for layout.
      await tester.pump(const Duration(milliseconds: 100));
    }
  } finally {
    FlutterError.onError = original;
  }
  return overflows;
}
