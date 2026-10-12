import 'package:flutter/widgets.dart';

import 'finding.dart';
import 'ignore.dart';

/// The WCAG contrast level to enforce for text.
enum ContrastLevel {
  /// WCAG 2.x AA: 4.5:1 for normal text, 3:1 for large text.
  aa(4.5, 3.0),

  /// WCAG 2.x AAA: 7:1 for normal text, 4.5:1 for large text.
  aaa(7.0, 4.5),

  /// Do not check text contrast.
  off(0, 0);

  const ContrastLevel(this.normalText, this.largeText);

  /// Minimum ratio for normal text.
  final double normalText;

  /// Minimum ratio for large text (see [isLargeText]).
  final double largeText;

  /// WCAG "large text": at least 18pt (24 logical px), or 14pt (18.66 px) when bold.
  static bool isLargeText(double fontSize, {required bool bold}) =>
      fontSize >= 24 || (bold && fontSize >= 18.66);

  /// The ratio required for text of [fontSize] (already scaled) and weight.
  double requiredRatio(double fontSize, {required bool bold}) =>
      isLargeText(fontSize, bold: bold) ? largeText : normalText;
}

/// What to check and how strict to be.
@immutable
class A11yConfig {
  /// Creates a config. Every argument has a sensible default.
  const A11yConfig({
    this.minTapTarget = androidTapTarget,
    this.contrast = ContrastLevel.aa,
    this.textScales = const <double>[1.0, 2.0],
    this.rtl = false,
    this.locales = const <Locale>[],
    this.rules = A11yRule.defaults,
    this.ignoreRules = const <A11yRule>{},
    this.ignore = const <A11yIgnore>[],
    this.failOn = A11ySeverity.warning,
    this.severityOverrides = const <A11yRule, A11ySeverity>{},
    this.colors = true,
    this.pathLandmarks = const <String>{},
  });

  /// Android / Material minimum tap target (48x48).
  static const double androidTapTarget = 48;

  /// iOS Human Interface Guidelines minimum tap target (44x44).
  static const double iosTapTarget = 44;

  /// Minimum width and height of a tappable node, in logical pixels.
  final double minTapTarget;

  /// Text contrast level. [ContrastLevel.off] skips the check.
  final ContrastLevel contrast;

  /// Text scale factors to run the audit at. 1.0 is always added as the baseline.
  final List<double> textScales;

  /// Also run every check with a right-to-left locale (`ar`), unless [locales] already contains
  /// one. The app must list that locale in `supportedLocales` for the layout to flip.
  final bool rtl;

  /// Extra locales to run the audit with (each one at every text scale).
  final List<Locale> locales;

  /// The rules to run.
  final Set<A11yRule> rules;

  /// Rules to skip (applied after [rules]).
  final Set<A11yRule> ignoreRules;

  /// Targeted ignores: by finder, key or label, optionally limited to some rules.
  final List<A11yIgnore> ignore;

  /// `expectAccessible` fails when a finding is at least this severe.
  final A11ySeverity failOn;

  /// Change the severity of a rule, e.g. make [A11yRule.imageLabel] an error.
  final Map<A11yRule, A11ySeverity> severityOverrides;

  /// Use ANSI colors in the failure message of `expectAccessible`.
  final bool colors;

  /// Extra widget type names to show in ancestor paths (e.g. your own `ProductCard`).
  final Set<String> pathLandmarks;

  /// Whether [rule] runs under this config.
  bool runs(A11yRule rule) => rules.contains(rule) && !ignoreRules.contains(rule);

  /// The severity [rule] reports with under this config.
  A11ySeverity severityOf(A11yRule rule) => severityOverrides[rule] ?? rule.defaultSeverity;

  /// The scales to run, ascending, always starting with 1.0.
  List<double> get effectiveTextScales {
    final Set<double> scales = <double>{1.0, ...textScales.where((double s) => s > 0)};
    return scales.toList()..sort();
  }

  /// The locales to run in addition to the app's current one.
  List<Locale> get effectiveLocales {
    final List<Locale> result = <Locale>[...locales];
    if (rtl && !result.any(isRtlLocale)) {
      result.add(const Locale('ar'));
    }
    return result;
  }

  /// Whether [locale] is written right to left.
  static bool isRtlLocale(Locale locale) => const <String>{
    'ar',
    'fa',
    'he',
    'iw',
    'ps',
    'ur',
    'ug',
    'yi',
    'ckb',
    'dv',
    'sd',
  }.contains(locale.languageCode);
}
