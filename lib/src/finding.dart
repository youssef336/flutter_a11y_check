import 'package:flutter/widgets.dart';

/// How serious a finding is.
///
/// The order matters: [A11yConfig.failOn] fails the audit for every finding whose severity is at
/// least as serious as the threshold.
enum A11ySeverity {
  /// A hint. Never fails an audit unless `failOn` is [info].
  info,

  /// Probably a real problem, but there are legitimate exceptions.
  warning,

  /// Breaks a WCAG / platform guideline.
  error;

  /// Whether this severity is at least as serious as [other].
  bool isAtLeast(A11ySeverity other) => index >= other.index;
}

/// The rules the audit knows about.
enum A11yRule {
  /// Tappable node smaller than the minimum tap target.
  tapTarget('tap-target', A11ySeverity.error, 'Tap target too small'),

  /// Tappable node without a label or tooltip.
  missingLabel('missing-label', A11ySeverity.error, 'Tappable without a label'),

  /// Text whose contrast against its background is below WCAG.
  contrast('contrast', A11ySeverity.error, 'Low text contrast'),

  /// Image without a semantic label that is not marked decorative.
  imageLabel('image-label', A11ySeverity.warning, 'Image without a label'),

  /// Layout that breaks (overflows, truncates, or ignores the setting) at a large font size.
  textScale('text-scale', A11ySeverity.error, 'Breaks at a large font size'),

  /// Several tappable nodes on the same screen announce the same label.
  duplicateLabel('duplicate-label', A11ySeverity.warning, 'Duplicate labels'),

  /// A label that says nothing ("Button", "Icon", "Tap here").
  genericLabel('generic-label', A11ySeverity.warning, 'Generic label'),

  /// Screen-reader / switch-access order that jumps against the visual reading order.
  focusOrder('focus-order', A11ySeverity.info, 'Focus order differs from visual order');

  const A11yRule(this.id, this.defaultSeverity, this.title);

  /// Stable kebab-case id, used in reports and JSON.
  final String id;

  /// Severity used unless the config overrides it.
  final A11ySeverity defaultSeverity;

  /// Short human-readable title.
  final String title;

  /// The rules that run when the config does not say otherwise (everything except
  /// [focusOrder], which is opt-in).
  static const Set<A11yRule> defaults = <A11yRule>{
    tapTarget,
    missingLabel,
    contrast,
    imageLabel,
    textScale,
    duplicateLabel,
    genericLabel,
  };

  /// Looks a rule up by its [id]. Returns null for unknown ids.
  static A11yRule? byId(String id) {
    for (final A11yRule rule in values) {
      if (rule.id == id) {
        return rule;
      }
    }
    return null;
  }
}

/// One accessibility problem found on the screen.
@immutable
class A11yFinding {
  /// Creates a finding. Rules create these; you normally only read them.
  const A11yFinding({
    required this.rule,
    required this.severity,
    required this.message,
    required this.suggestion,
    this.widget,
    this.path,
    this.label,
    this.rect,
    this.variant,
    this.data = const <String, Object?>{},
    this.element,
    this.dedupeKey,
  });

  /// The rule that produced this finding.
  final A11yRule rule;

  /// How serious it is (after config overrides).
  final A11ySeverity severity;

  /// What is wrong, in one sentence.
  final String message;

  /// How to fix it.
  final String suggestion;

  /// The widget type the finding is about, e.g. `IconButton`.
  final String? widget;

  /// Readable ancestor path, e.g. `LoginScreen > Scaffold > AppBar > IconButton`.
  final String? path;

  /// The text or semantic label involved, if any.
  final String? label;

  /// Where it is on screen, in logical pixels.
  final Rect? rect;

  /// The run that found it, e.g. `200% · rtl`.
  final String? variant;

  /// Rule-specific measurements (sizes, ratios, colors). JSON-friendly values only.
  final Map<String, Object?> data;

  /// The element the finding points at. Used for ignores; not serialized.
  final Element? element;

  /// Identity used to merge the same problem seen in several runs. Not serialized.
  final String? dedupeKey;

  /// A copy with some fields replaced.
  A11yFinding copyWith({A11ySeverity? severity, String? variant}) {
    return A11yFinding(
      rule: rule,
      severity: severity ?? this.severity,
      message: message,
      suggestion: suggestion,
      widget: widget,
      path: path,
      label: label,
      rect: rect,
      variant: variant ?? this.variant,
      data: data,
      element: element,
      dedupeKey: dedupeKey,
    );
  }

  /// JSON-friendly map.
  Map<String, Object?> toJson() {
    final Rect? r = rect;
    return <String, Object?>{
      'rule': rule.id,
      'severity': severity.name,
      'message': message,
      'suggestion': suggestion,
      if (widget != null) 'widget': widget,
      if (path != null) 'path': path,
      if (label != null) 'label': label,
      if (r != null)
        'rect': <String, double>{
          'left': _round(r.left),
          'top': _round(r.top),
          'width': _round(r.width),
          'height': _round(r.height),
        },
      if (variant != null) 'variant': variant,
      if (data.isNotEmpty) 'data': data,
    };
  }

  static double _round(double v) => (v * 10).roundToDouble() / 10;

  @override
  String toString() => '[${severity.name}] ${rule.id}: $message';
}
