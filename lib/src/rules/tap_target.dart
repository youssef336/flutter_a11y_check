import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../context.dart';
import '../finding.dart';
import '../format.dart';
import '../widget_path.dart';

/// Tappable semantics nodes smaller than the minimum tap target.
///
/// Same traversal and skips as `androidTapTargetGuideline` / `iOSTapTargetGuideline` in
/// `flutter_test` (links, hidden nodes, nodes cut by a scrollable or the screen edge), but it
/// collects every violation with the widget, its path and its rect.
List<A11yFinding> checkTapTargets(AuditContext ctx) {
  final double min = ctx.config.minTapTarget;
  final List<A11yFinding> findings = <A11yFinding>[];
  final Set<int> mergedInto = ctx.nodesWithMergedGestures;
  for (final (RenderView view, SemanticsNode root) in ctx.semanticsRoots) {
    final Rect viewRect = Offset.zero & view.flutterView.physicalSize;
    for (final SemanticsNode node in AuditContext.flatten(root)) {
      if (node.isMergedIntoParent || mergedInto.contains(node.id)) {
        continue;
      }
      final SemanticsData data = node.getSemanticsData();
      if (!AuditContext.isTappable(data) ||
          data.flagsCollection.isHidden ||
          data.flagsCollection.isLink) {
        continue;
      }
      if (_cutByScrollable(node) || _atBoundary(AuditContext.physicalRect(node), viewRect)) {
        continue;
      }
      final Rect rect = AuditContext.logicalRect(node, view);
      if (rect.width >= min - precisionErrorTolerance &&
          rect.height >= min - precisionErrorTolerance) {
        continue;
      }
      final WidgetDescription where = ctx.describeNode(node, rect);
      final String label = data.label.isNotEmpty ? data.label : data.tooltip;
      final String size = '${fmtNum(rect.width)}x${fmtNum(rect.height)}';
      final String minSize = '${fmtNum(min)}x${fmtNum(min)}';
      findings.add(
        ctx.finding(
          rule: A11yRule.tapTarget,
          message:
              '${where.widget}${label.isEmpty ? '' : ' "$label"'} is $size, '
              'smaller than the $minSize minimum tap target.',
          suggestion: _suggestion(where.widget, min),
          where: where,
          label: label.isEmpty ? null : label,
          rect: rect,
          data: <String, Object?>{
            'width': round1(rect.width),
            'height': round1(rect.height),
            'min': min,
          },
          dedupeKey: '${identityHashCode(where.element)}',
        ),
      );
    }
  }
  for (final MergedGesture g in ctx.mergedGestures) {
    final Rect viewRect = Offset.zero & g.view.flutterView.physicalSize;
    final double dpr = g.view.flutterView.devicePixelRatio;
    final Rect physical = Rect.fromLTRB(
      g.rect.left * dpr,
      g.rect.top * dpr,
      g.rect.right * dpr,
      g.rect.bottom * dpr,
    );
    if (_atBoundary(physical, viewRect) ||
        (g.rect.width >= min - precisionErrorTolerance &&
            g.rect.height >= min - precisionErrorTolerance)) {
      continue;
    }
    final WidgetDescription where = ctx.describeElement(g.element);
    findings.add(
      ctx.finding(
        rule: A11yRule.tapTarget,
        message:
            '${where.widget} is ${fmtNum(g.rect.width)}x${fmtNum(g.rect.height)}, smaller than '
            'the ${fmtNum(min)}x${fmtNum(min)} minimum tap target.',
        suggestion: _suggestion(where.widget, min),
        where: where,
        rect: g.rect,
        data: <String, Object?>{
          'width': round1(g.rect.width),
          'height': round1(g.rect.height),
          'min': min,
        },
        dedupeKey: '${identityHashCode(g.element)}',
      ),
    );
  }
  return findings;
}

String _suggestion(String widget, double min) {
  final String m = fmtNum(min);
  switch (widget) {
    case 'IconButton':
      return 'Remove the fixed size / zero padding / shrinkWrap tap target size so the button keeps '
          'its default ${m}x$m, or wrap it in SizedBox.square(dimension: $m).';
    case 'TextButton':
    case 'ElevatedButton':
    case 'OutlinedButton':
    case 'FilledButton':
      return 'Use MaterialTapTargetSize.padded (the default) instead of shrinkWrap, or set '
          'minimumSize: Size($m, $m) in the button style.';
    case 'Checkbox':
    case 'Radio':
    case 'Switch':
      return 'Keep materialTapTargetSize: MaterialTapTargetSize.padded, or put it in a '
          'CheckboxListTile / SwitchListTile so the whole row is tappable.';
    default:
      return 'Give the tappable area at least ${m}x$m: add padding inside the gesture detector or '
          'wrap it in ConstrainedBox(constraints: BoxConstraints(minWidth: $m, minHeight: $m)).';
  }
}

bool _cutByScrollable(SemanticsNode node) {
  Rect bounds = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    final Matrix4? transform = current.transform;
    if (transform != null) {
      bounds = MatrixUtils.transformRect(transform, bounds);
    }
    if (current.flagsCollection.hasImplicitScrolling && _atBoundary(bounds, current.rect)) {
      return true;
    }
    current = current.parent;
  }
  return false;
}

bool _atBoundary(Rect child, Rect parent) {
  const double gap = 0.001;
  return !(child.left - parent.left > gap &&
      parent.right - child.right > gap &&
      child.top - parent.top > gap &&
      parent.bottom - child.bottom > gap);
}
