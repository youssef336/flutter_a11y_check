import 'package:flutter/widgets.dart';
import 'package:flutter_a11y_check/flutter_a11y_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text scales always start at 1.0, sorted, without duplicates or non-positive values', () {
    expect(const A11yConfig().effectiveTextScales, <double>[1.0, 2.0]);
    expect(const A11yConfig(textScales: <double>[2.0, 0, 1.5, 2.0]).effectiveTextScales, <double>[
      1.0,
      1.5,
      2.0,
    ]);
  });

  test('rtl adds Arabic unless an RTL locale is already listed', () {
    expect(const A11yConfig().effectiveLocales, isEmpty);
    expect(const A11yConfig(rtl: true).effectiveLocales, <Locale>[const Locale('ar')]);
    expect(const A11yConfig(rtl: true, locales: <Locale>[Locale('he')]).effectiveLocales, <Locale>[
      const Locale('he'),
    ]);
    expect(A11yConfig.isRtlLocale(const Locale('fa')), isTrue);
    expect(A11yConfig.isRtlLocale(const Locale('en')), isFalse);
  });

  test('rules, ignoreRules and severity overrides', () {
    const A11yConfig config = A11yConfig(
      ignoreRules: <A11yRule>{A11yRule.contrast},
      severityOverrides: <A11yRule, A11ySeverity>{A11yRule.imageLabel: A11ySeverity.error},
    );
    expect(config.runs(A11yRule.tapTarget), isTrue);
    expect(config.runs(A11yRule.contrast), isFalse);
    expect(config.runs(A11yRule.focusOrder), isFalse);
    expect(config.severityOf(A11yRule.imageLabel), A11ySeverity.error);
    expect(config.severityOf(A11yRule.duplicateLabel), A11ySeverity.warning);
  });
}
