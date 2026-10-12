import 'package:flutter/rendering.dart';

import '../context.dart';
import '../finding.dart';
import '../format.dart';
import '../widget_path.dart';

/// Labels that tell a screen-reader user nothing about what the control does.
const Set<String> genericLabels = <String>{
  'button',
  'btn',
  'icon',
  'image',
  'img',
  'picture',
  'photo',
  'tap',
  'tap here',
  'click',
  'click here',
  'press',
  'link',
  'label',
  'untitled',
  'item',
};

class _Tappable {
  const _Tappable(this.node, this.data, this.rect, this.view);
  final SemanticsNode node;
  final SemanticsData data;
  final Rect rect;
  final RenderView view;
}

List<_Tappable> _tappables(AuditContext ctx) {
  final List<_Tappable> out = <_Tappable>[];
  for (final (RenderView view, SemanticsNode root) in ctx.semanticsRoots) {
    for (final SemanticsNode node in AuditContext.flatten(root)) {
      if (!AuditContext.isPerceivable(node) || node.flagsCollection.isTextField) {
        continue;
      }
      final SemanticsData data = node.getSemanticsData();
      if (!AuditContext.isTappable(data)) {
        continue;
      }
      out.add(_Tappable(node, data, AuditContext.logicalRect(node, view), view));
    }
  }
  return out;
}

/// Tappable nodes with neither a label nor a tooltip (same test as `labeledTapTargetGuideline`,
/// with the widget named and a fix that fits it).
List<A11yFinding> checkMissingLabels(AuditContext ctx) {
  final List<A11yFinding> findings = <A11yFinding>[];
  final Set<int> mergedInto = ctx.nodesWithMergedGestures;
  for (final _Tappable t in _tappables(ctx)) {
    if (t.data.label.trim().isNotEmpty ||
        t.data.tooltip.trim().isNotEmpty ||
        mergedInto.contains(t.node.id)) {
      continue;
    }
    final WidgetDescription where = ctx.describeNode(t.node, t.rect);
    findings.add(
      ctx.finding(
        rule: A11yRule.missingLabel,
        message:
            '${where.widget} can be tapped but has no label, so a screen reader announces only '
            '"button" (or nothing).',
        suggestion: _missingLabelFix(where.widget),
        where: where,
        rect: t.rect,
        dedupeKey: '${identityHashCode(where.element)}',
      ),
    );
  }
  for (final MergedGesture g in ctx.mergedGestures) {
    if (g.hasLabel) {
      continue;
    }
    final WidgetDescription where = ctx.describeElement(g.element);
    findings.add(
      ctx.finding(
        rule: A11yRule.missingLabel,
        message:
            '${where.widget} can be tapped but nothing inside it has a label, so a screen '
            'reader cannot say what it does.',
        suggestion: _missingLabelFix(where.widget),
        where: where,
        rect: g.rect,
        dedupeKey: '${identityHashCode(g.element)}',
      ),
    );
  }
  return findings;
}

String _missingLabelFix(String widget) {
  switch (widget) {
    case 'IconButton':
    case 'FloatingActionButton':
    case 'BackButton':
    case 'CloseButton':
      return "Add tooltip: 'Describe the action' - Flutter uses the tooltip as the label.";
    case 'GestureDetector':
    case 'InkWell':
    case 'InkResponse':
      return "Wrap it in Semantics(label: 'Describe the action', button: true, child: ...), or "
          'use an IconButton with a tooltip instead.';
    case 'Checkbox':
    case 'Switch':
    case 'Radio':
    case 'Slider':
      return 'Use the ListTile variant (CheckboxListTile, SwitchListTile, ...) with a title, or '
          "wrap it in Semantics(label: '...').";
    default:
      return "Give it a visible text child, a tooltip, or wrap it in Semantics(label: '...').";
  }
}

/// Several tappable nodes announcing the same label, and labels that say nothing.
List<A11yFinding> checkDuplicateAndGenericLabels(AuditContext ctx) {
  final List<A11yFinding> findings = <A11yFinding>[];
  final bool duplicates = ctx.config.runs(A11yRule.duplicateLabel);
  final bool generic = ctx.config.runs(A11yRule.genericLabel);
  final Map<String, List<_Tappable>> byLabel = <String, List<_Tappable>>{};
  for (final _Tappable t in _tappables(ctx)) {
    final String label = (t.data.label.isNotEmpty ? t.data.label : t.data.tooltip).trim();
    if (label.isEmpty) {
      continue;
    }
    byLabel.putIfAbsent(label.toLowerCase(), () => <_Tappable>[]).add(t);
    if (generic && genericLabels.contains(label.toLowerCase())) {
      final WidgetDescription where = ctx.describeNode(t.node, t.rect);
      findings.add(
        ctx.finding(
          rule: A11yRule.genericLabel,
          message:
              '${where.widget} is labelled "$label", which does not say what it does '
              '(screen readers already announce the role).',
          suggestion:
              "Describe the action or destination, e.g. 'Delete message' or 'Open settings'.",
          where: where,
          label: label,
          rect: t.rect,
          dedupeKey: '${identityHashCode(where.element)}',
        ),
      );
    }
  }
  if (!duplicates) {
    return findings;
  }
  for (final List<_Tappable> group in byLabel.values) {
    if (group.length < 2) {
      continue;
    }
    final String label =
        (group.first.data.label.isNotEmpty ? group.first.data.label : group.first.data.tooltip)
            .trim();
    final List<WidgetDescription> places = <WidgetDescription>[
      for (final _Tappable t in group) ctx.describeNode(t.node, t.rect),
    ];
    final Set<String> types = places.map((WidgetDescription d) => d.widget).toSet();
    findings.add(
      ctx.finding(
        rule: A11yRule.duplicateLabel,
        message:
            '${group.length} tappable ${types.join('/')} widgets on this screen are all '
            'labelled "${clip(label)}"; screen-reader users cannot tell them apart.',
        suggestion:
            "Make each label unique by adding context, e.g. 'Delete Invoice #12', or merge "
            'the repeated controls into one.',
        where: places.first,
        label: label,
        rect: group.first.rect,
        data: <String, Object?>{
          'count': group.length,
          'paths': places.map((WidgetDescription d) => d.path).toList(),
        },
        dedupeKey: label.toLowerCase(),
      ),
    );
  }
  return findings;
}
