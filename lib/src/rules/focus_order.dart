import 'package:flutter/rendering.dart';

import '../context.dart';
import '../finding.dart';
import '../format.dart';
import '../widget_path.dart';

class _Stop {
  const _Stop(this.node, this.rect, this.label);
  final SemanticsNode node;
  final Rect rect;
  final String label;
}

/// Compares the order a screen reader / switch device visits interactive nodes (semantics
/// traversal order) with the visual reading order: top to bottom, then start to end (right to
/// left for RTL). Reports every step that jumps backwards.
List<A11yFinding> checkFocusOrder(AuditContext ctx) {
  final List<A11yFinding> findings = <A11yFinding>[];
  final bool rtl = ctx.textDirection == TextDirection.rtl;
  for (final (RenderView view, SemanticsNode root) in ctx.semanticsRoots) {
    final List<_Stop> stops = <_Stop>[];
    void walk(SemanticsNode node) {
      if (node.isMergedIntoParent || node.isInvisible || node.flagsCollection.isHidden) {
        return;
      }
      final SemanticsData data = node.getSemanticsData();
      final bool focusable =
          AuditContext.isTappable(data) ||
          node.flagsCollection.isTextField ||
          data.hasAction(SemanticsAction.focus);
      if (focusable && node != root) {
        final String label = data.label.isNotEmpty ? data.label : data.tooltip;
        stops.add(_Stop(node, AuditContext.logicalRect(node, view), label));
      }
      for (final SemanticsNode child in node.debugListChildrenInOrder(
        DebugSemanticsDumpOrder.traversalOrder,
      )) {
        walk(child);
      }
    }

    walk(root);
    for (var i = 1; i < stops.length; i++) {
      final _Stop from = stops[i - 1];
      final _Stop to = stops[i];
      final bool jumpsUp = to.rect.bottom <= from.rect.top + 0.5;
      final bool sameRow =
          to.rect.top < from.rect.bottom - 0.5 && from.rect.top < to.rect.bottom - 0.5;
      final bool jumpsBack =
          sameRow &&
          (rtl ? to.rect.left >= from.rect.right - 0.5 : to.rect.right <= from.rect.left + 0.5);
      if (!jumpsUp && !jumpsBack) {
        continue;
      }
      final WidgetDescription where = ctx.describeNode(to.node, to.rect);
      final String fromName = from.label.isEmpty ? 'the previous control' : '"${clip(from.label)}"';
      final String toName = to.label.isEmpty ? where.widget : '"${clip(to.label)}"';
      final String direction = jumpsUp
          ? 'back up the screen'
          : (rtl ? 'back to the right' : 'back to the left');
      findings.add(
        ctx.finding(
          rule: A11yRule.focusOrder,
          message:
              'Screen-reader / switch order goes from $fromName to $toName, $direction, '
              'although $toName comes first visually.',
          suggestion:
              'Check this order is intended. Reorder the widgets, group related controls with '
              'MergeSemantics / FocusTraversalGroup, or set Semantics(sortKey: OrdinalSortKey(n)).',
          where: where,
          label: to.label.isEmpty ? null : to.label,
          rect: to.rect,
          data: <String, Object?>{'position': i + 1, 'from': from.label, 'to': to.label},
          dedupeKey: '${from.node.id}->${to.node.id}',
        ),
      );
    }
  }
  return findings;
}
