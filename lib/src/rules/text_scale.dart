import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../context.dart';
import '../finding.dart';
import '../format.dart';
import '../widget_path.dart';

/// Whether [details] is a layout overflow report (`A RenderFlex overflowed by ...`).
bool isOverflowError(FlutterErrorDetails details) =>
    details.exceptionAsString().contains('overflowed by');

/// Visible text that is truncated (ellipsis / clip / maxLines) right now.
Set<Element> truncatedTexts() {
  final Set<Element> out = <Element>{};
  for (final Element element in find.byType(RichText).evaluate()) {
    final RenderObject? ro = element.renderObject;
    if (ro is RenderParagraph && ro.hasSize && ro.didExceedMaxLines) {
      out.add(element);
    }
  }
  return out;
}

/// Layout that breaks when the user's font size goes up: overflow errors, text that becomes
/// truncated, and text that ignores the font-size setting entirely.
List<A11yFinding> checkTextScale(AuditContext ctx) {
  final List<A11yFinding> findings = <A11yFinding>[];
  final double scale = ctx.textScale;
  final String percent = '${(scale * 100).round()}%';

  for (final FlutterErrorDetails details in ctx.layoutErrors) {
    final String first = details.exceptionAsString().split('\n').first.trim();
    final RenderObject? culprit = _renderObjectOf(details);
    final Element? creator = _creatorOf(culprit);
    final WidgetDescription? where = creator == null ? null : ctx.describeElement(creator);
    final Rect? rect = creator == null ? null : AuditContext.elementRect(creator);
    final String what = where?.widget ?? 'A layout';
    findings.add(
      ctx.finding(
        rule: A11yRule.textScale,
        message: scale == 1.0
            ? '$what overflows even at 100% font size: $first'
            : 'Breaks at $percent font size: $what overflows ($first).',
        suggestion: _overflowFix(where?.widget),
        where: where,
        rect: rect,
        data: <String, Object?>{'textScale': scale, 'error': first},
        dedupeKey: '${identityHashCode(culprit ?? details)}',
      ),
    );
  }

  if (scale <= 1.0) {
    return findings;
  }

  for (final Element element in truncatedTexts()) {
    if (ctx.baselineTruncated.contains(element)) {
      continue;
    }
    final RichText widget = element.widget as RichText;
    final String text = widget.text.toPlainText();
    final Element subject = WidgetPaths.textWidgetOf(element);
    final WidgetDescription where = ctx.describeElement(subject);
    findings.add(
      ctx.finding(
        rule: A11yRule.textScale,
        severity: A11ySeverity.warning,
        message: 'Breaks at $percent font size: "${clip(text)}" gets cut off (maxLines/ellipsis).',
        suggestion:
            'Let the text wrap (drop maxLines or raise it) and let its container grow; avoid '
            'fixed heights around text.',
        where: where,
        label: text,
        rect: AuditContext.elementRect(element),
        data: <String, Object?>{'textScale': scale},
        dedupeKey: 'truncated|${identityHashCode(element)}',
      ),
    );
  }

  final List<Element> fixed = <Element>[];
  for (final Element element in find.byType(RichText).hitTestable().evaluate()) {
    final RichText widget = element.widget as RichText;
    final String text = widget.text.toPlainText();
    if (text.trim().isEmpty || WidgetPaths.isIconText(element, text)) {
      continue;
    }
    if (widget.textScaler.scale(14) <= 14.01) {
      fixed.add(element);
    }
  }
  if (fixed.isNotEmpty) {
    final Element subject = WidgetPaths.textWidgetOf(fixed.first);
    final WidgetDescription where = ctx.describeElement(subject);
    final String sample = clip((fixed.first.widget as RichText).text.toPlainText());
    findings.add(
      ctx.finding(
        rule: A11yRule.textScale,
        severity: A11ySeverity.warning,
        message:
            '${fixed.length} text widget${fixed.length == 1 ? ' ignores' : 's ignore'} the font-size '
            'setting (e.g. "$sample" stays at 100% when the user asks for $percent).',
        suggestion:
            'Remove textScaler: TextScaler.noScaling / a MediaQuery that pins textScaler to 1.0. '
            'If you must limit it, clamp instead: '
            'MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 2.0).',
        where: where,
        label: sample,
        rect: AuditContext.elementRect(fixed.first),
        data: <String, Object?>{'textScale': scale, 'count': fixed.length},
        dedupeKey: 'noscale',
      ),
    );
  }
  return findings;
}

String _overflowFix(String? widget) {
  switch (widget) {
    case 'Row':
    case 'Flex':
      return 'Wrap the text children in Expanded/Flexible so they can wrap, or switch to Wrap '
          'when the content does not fit on one line.';
    case 'Column':
      return 'Make the screen scrollable (SingleChildScrollView / ListView) and avoid fixed '
          'heights around text.';
    default:
      return 'Let the container grow with its text: remove fixed heights/widths, use Flexible, '
          'or make the area scrollable.';
  }
}

RenderObject? _renderObjectOf(FlutterErrorDetails details) {
  final InformationCollector? collector = details.informationCollector;
  if (collector == null) {
    return null;
  }
  for (final DiagnosticsNode node in collector()) {
    final Object? value = node.value;
    if (value is RenderObject) {
      return value;
    }
  }
  return null;
}

Element? _creatorOf(RenderObject? ro) {
  final Object? creator = ro?.debugCreator;
  if (creator is DebugCreator) {
    final Element element = creator.element;
    return element.mounted ? element : null;
  }
  return null;
}
