import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../context.dart';
import '../finding.dart';
import '../widget_path.dart';

/// `Image` widgets that have no `semanticLabel` and are not marked decorative.
///
/// An image is fine when it has a label, sets `excludeFromSemantics: true`, sits under
/// `ExcludeSemantics` / `Semantics(excludeSemantics: true)`, or is part of a semantics node that
/// already has a label (an image inside a labelled button or list tile).
List<A11yFinding> checkImages(AuditContext ctx) {
  final List<A11yFinding> findings = <A11yFinding>[];
  for (final Element element in find.byType(Image).evaluate()) {
    final Image image = element.widget as Image;
    if (image.excludeFromSemantics || (image.semanticLabel?.trim().isNotEmpty ?? false)) {
      continue;
    }
    if (_excludedByAncestor(element) || _labelledByContainer(element)) {
      continue;
    }
    final Rect? rect = AuditContext.elementRect(element);
    if (rect == null || rect.isEmpty) {
      continue;
    }
    final WidgetDescription where = ctx.describeElement(element);
    findings.add(
      ctx.finding(
        rule: A11yRule.imageLabel,
        message:
            'Image has no semanticLabel and is not marked decorative, so screen readers either '
            'skip it silently or announce just "image".',
        suggestion:
            "If it carries meaning add semanticLabel: 'What the image shows'; if it is "
            'decorative set excludeFromSemantics: true.',
        where: where,
        rect: rect,
        dedupeKey: '${identityHashCode(element)}',
      ),
    );
  }
  return findings;
}

bool _excludedByAncestor(Element element) {
  var excluded = false;
  element.visitAncestorElements((Element ancestor) {
    final Widget w = ancestor.widget;
    if (w is ExcludeSemantics && w.excluding) {
      excluded = true;
    } else if (w is Semantics && w.excludeSemantics) {
      excluded = true;
    }
    return !excluded;
  });
  return excluded;
}

bool _labelledByContainer(Element element) {
  RenderObject? current = element.renderObject;
  while (current != null) {
    final SemanticsNode? node = current.debugSemantics;
    if (node != null) {
      SemanticsNode effective = node;
      while (effective.isMergedIntoParent && effective.parent != null) {
        effective = effective.parent!;
      }
      final SemanticsData data = effective.getSemanticsData();
      final bool isImageNode = data.flagsCollection.isImage;
      return !isImageNode &&
          AuditContext.isTappable(data) &&
          (data.label.trim().isNotEmpty || data.tooltip.trim().isNotEmpty);
    }
    current = current.parent;
  }
  return false;
}
