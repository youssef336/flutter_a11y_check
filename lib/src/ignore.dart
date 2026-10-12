import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'finding.dart';

/// Silences findings that are known and accepted.
///
/// ```dart
/// A11yConfig(ignore: [
///   A11yIgnore.rule(A11yRule.duplicateLabel),
///   A11yIgnore.key(const Key('brand-logo'), rules: {A11yRule.imageLabel}),
///   A11yIgnore.finder(find.byType(MapView), reason: 'third-party widget'),
///   A11yIgnore.label('Delete', rules: {A11yRule.duplicateLabel}),
/// ])
/// ```
///
/// A finder or key ignore covers the matched widget and everything inside it.
@immutable
class A11yIgnore {
  /// Ignores every finding of [rule].
  A11yIgnore.rule(A11yRule rule, {this.reason})
    : rules = <A11yRule>{rule},
      finder = null,
      label = null;

  /// Ignores findings on the widgets matched by [finder] (and their descendants).
  ///
  /// [rules] limits the ignore to some rules; null means all rules.
  const A11yIgnore.finder(Finder this.finder, {this.rules, this.reason}) : label = null;

  /// Ignores findings on the widget with [key] (and its descendants).
  A11yIgnore.key(Key key, {this.rules, this.reason})
    : finder = find.byKey(key, skipOffstage: false),
      label = null;

  /// Ignores findings whose label is exactly [label].
  const A11yIgnore.label(String this.label, {this.rules, this.reason}) : finder = null;

  /// Rules this ignore applies to; null means every rule.
  final Set<A11yRule>? rules;

  /// Widgets this ignore covers; null means "anywhere".
  final Finder? finder;

  /// Label this ignore matches; null means "any label".
  final String? label;

  /// Why it is ignored. Only for humans reading the test.
  final String? reason;

  /// Whether this ignore silences [finding].
  bool appliesTo(A11yFinding finding) {
    final Set<A11yRule>? limited = rules;
    if (limited != null && !limited.contains(finding.rule)) {
      return false;
    }
    final String? wanted = label;
    if (wanted != null && finding.label?.trim() != wanted.trim()) {
      return false;
    }
    final Finder? target = finder;
    if (target != null) {
      final Element? element = finding.element;
      if (element == null) {
        return false;
      }
      final Set<Element> targets = target.evaluate().toSet();
      if (targets.isEmpty) {
        return false;
      }
      if (targets.contains(element)) {
        return true;
      }
      var covered = false;
      element.visitAncestorElements((Element ancestor) {
        covered = targets.contains(ancestor);
        return !covered;
      });
      return covered;
    }
    return true;
  }
}
