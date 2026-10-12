import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'config.dart';
import 'finding.dart';
import 'widget_path.dart';

/// Everything a rule needs for one run (one text scale, one locale).
class AuditContext {
  /// Creates a context and indexes semantics nodes to the elements that own them.
  AuditContext({required this.tester, required this.config, required this.variant}) {
    final Element? root = tester.binding.rootElement;
    if (root != null) {
      _index(root);
    }
  }

  /// The tester of the running widget test.
  final WidgetTester tester;

  /// Active config.
  final A11yConfig config;

  /// Label of this run, e.g. `200%` or `150% · rtl`.
  final String variant;

  /// Errors (overflows) reported while the screen was laid out for this run.
  final List<FlutterErrorDetails> layoutErrors = <FlutterErrorDetails>[];

  /// Text that was already truncated at 100%, so it is not blamed on the larger font.
  Set<Element> baselineTruncated = <Element>{};

  /// The text scale of this run.
  double textScale = 1.0;

  final Map<int, Element> _nodeOwners = <int, Element>{};

  void _index(Element element) {
    if (element is RenderObjectElement) {
      final SemanticsNode? node = element.renderObject.debugSemantics;
      if (node != null) {
        _nodeOwners.putIfAbsent(node.id, () => element);
      }
    }
    element.visitChildren(_index);
  }

  /// The render views of the test, with their semantics roots.
  Iterable<(RenderView, SemanticsNode)> get semanticsRoots sync* {
    for (final RenderView view in tester.binding.renderViews) {
      final SemanticsNode? root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root != null) {
        yield (view, root);
      }
    }
  }

  /// Every semantics node under [root], depth first, in tree (not traversal) order.
  static List<SemanticsNode> flatten(SemanticsNode root) {
    final List<SemanticsNode> out = <SemanticsNode>[];
    void walk(SemanticsNode node) {
      out.add(node);
      node.visitChildren((SemanticsNode child) {
        walk(child);
        return true;
      });
    }

    walk(root);
    return out;
  }

  /// Whether [data] can be tapped or long-pressed.
  static bool isTappable(SemanticsData data) =>
      data.hasAction(ui.SemanticsAction.tap) || data.hasAction(ui.SemanticsAction.longPress);

  /// Whether [node] is part of what a user can perceive right now.
  static bool isPerceivable(SemanticsNode node) =>
      !node.isMergedIntoParent && !node.isInvisible && !node.flagsCollection.isHidden;

  /// The rect of [node] in physical pixels of [view].
  static Rect physicalRect(SemanticsNode node) {
    Rect rect = node.rect;
    SemanticsNode? current = node;
    while (current != null) {
      final Matrix4? transform = current.transform;
      if (transform != null) {
        rect = MatrixUtils.transformRect(transform, rect);
      }
      current = current.parent;
    }
    return rect;
  }

  /// The rect of [node] in logical pixels.
  static Rect logicalRect(SemanticsNode node, RenderView view) {
    final Rect physical = physicalRect(node);
    final double dpr = view.flutterView.devicePixelRatio;
    return Rect.fromLTRB(
      physical.left / dpr,
      physical.top / dpr,
      physical.right / dpr,
      physical.bottom / dpr,
    );
  }

  /// The element that owns [node], if any.
  Element? ownerOf(SemanticsNode node) => _nodeOwners[node.id];

  /// Describes the widget behind [node] (type, path) using [rect] to pick the right ancestor.
  WidgetDescription describeNode(SemanticsNode node, Rect rect) {
    final Element? owner = ownerOf(node);
    if (owner == null) {
      return const WidgetDescription(widget: 'Semantics', path: 'Semantics');
    }
    return WidgetPaths.describe(owner, nodeRect: rect, landmarks: config.pathLandmarks);
  }

  /// Describes the widget of [element].
  WidgetDescription describeElement(Element element) =>
      WidgetPaths.describe(element, landmarks: config.pathLandmarks, exact: true);

  /// Global rect of the render box under [element], in logical pixels.
  static Rect? elementRect(Element element) {
    final RenderObject? ro = element.renderObject;
    if (ro is! RenderBox || !ro.hasSize || !ro.attached) {
      return null;
    }
    return MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);
  }

  /// Builds a finding with the config's severity for [rule].
  A11yFinding finding({
    required A11yRule rule,
    required String message,
    required String suggestion,
    required String dedupeKey,
    WidgetDescription? where,
    String? label,
    Rect? rect,
    Map<String, Object?> data = const <String, Object?>{},
    Element? element,
    A11ySeverity? severity,
  }) {
    return A11yFinding(
      rule: rule,
      severity: severity ?? config.severityOf(rule),
      message: message,
      suggestion: suggestion,
      widget: where?.widget,
      path: where?.path,
      label: label,
      rect: rect,
      variant: variant,
      data: data,
      element: element ?? where?.element,
      dedupeKey: '${rule.id}|$dedupeKey',
    );
  }

  List<MergedGesture>? _merged;

  /// Gesture widgets (`GestureDetector`, `InkWell`, `InkResponse`) that have no semantics node
  /// of their own: their tap is merged into a bigger surrounding node, so the node-based checks
  /// cannot see their real size or label. Widgets inside Material controls are left out.
  List<MergedGesture> get mergedGestures => _merged ??= _findMergedGestures();

  /// Ids of the nodes that [mergedGestures] were merged into.
  Set<int> get nodesWithMergedGestures => <int>{
    for (final MergedGesture g in mergedGestures) g.node.id,
  };

  List<MergedGesture> _findMergedGestures() {
    final List<MergedGesture> out = <MergedGesture>[];
    final List<Element> candidates = <Element>[
      ...find.byType(GestureDetector).evaluate(),
      ...find.byType(InkWell).evaluate(),
      ...find.byType(InkResponse).evaluate(),
    ];
    for (final Element element in candidates) {
      if (!_hasTapHandler(element.widget)) {
        continue;
      }
      final Rect? rect = elementRect(element);
      if (rect == null || rect.isEmpty || _insideControl(element, rect)) {
        continue;
      }
      SemanticsNode? node = nearestNode(element.renderObject);
      if (node == null) {
        continue;
      }
      while (node!.isMergedIntoParent && node.parent != null) {
        node = node.parent;
      }
      final RenderView? view = viewOf(element.renderObject);
      if (view == null || !isTappable(node.getSemanticsData())) {
        continue;
      }
      final Rect nodeRect = logicalRect(node, view);
      // Same box, or the same box plus a control's tap-target padding (Material buttons pad a
      // 40x40 ink well to a 48x48 node): the node-based checks already cover it.
      if (_sameRect(nodeRect, rect, tolerance: 8)) {
        continue;
      }
      out.add(
        MergedGesture(
          element: element,
          rect: rect,
          node: node,
          view: view,
          hasLabel: _hasLabel(element),
        ),
      );
    }
    return out;
  }

  static bool _hasTapHandler(Widget widget) {
    if (widget is GestureDetector) {
      return !widget.excludeFromSemantics &&
          (widget.onTap != null || widget.onLongPress != null || widget.onDoubleTap != null);
    }
    if (widget is InkResponse) {
      return !widget.excludeFromSemantics &&
          (widget.onTap != null || widget.onLongPress != null || widget.onDoubleTap != null);
    }
    return false;
  }

  /// Whether [element] is part of a bigger control (the ink well inside a `TextButton`, the
  /// gesture detector inside an `InkWell`). Only ancestors of about the same size count.
  static bool _insideControl(Element element, Rect rect) {
    final Rect limit = rect.inflate(12);
    var inside = false;
    var depth = 0;
    element.visitAncestorElements((Element ancestor) {
      depth++;
      final Rect? box = elementRect(ancestor);
      if (box != null &&
          (box.left < limit.left ||
              box.top < limit.top ||
              box.right > limit.right ||
              box.bottom > limit.bottom)) {
        return false;
      }
      final String name = WidgetPaths.nameOf(ancestor.widget);
      inside =
          (WidgetPaths.controls.contains(name) &&
              name != 'Text' &&
              name != 'Icon' &&
              name != 'Image') ||
          WidgetPaths.gestures.contains(name);
      return !inside && depth < 40;
    });
    return inside;
  }

  static bool _sameRect(Rect a, Rect b, {double tolerance = 1}) =>
      (a.left - b.left).abs() <= tolerance &&
      (a.top - b.top).abs() <= tolerance &&
      (a.right - b.right).abs() <= tolerance &&
      (a.bottom - b.bottom).abs() <= tolerance;

  static bool _hasLabel(Element element) {
    var labelled = false;
    var depth = 0;
    element.visitAncestorElements((Element ancestor) {
      depth++;
      final Widget w = ancestor.widget;
      labelled =
          (w is Semantics && (w.properties.label?.trim().isNotEmpty ?? false)) ||
          (w is Tooltip && (w.message?.trim().isNotEmpty ?? false));
      return !labelled && depth < 4;
    });
    if (labelled) {
      return true;
    }
    void visit(Element e) {
      if (labelled) {
        return;
      }
      final Widget w = e.widget;
      if (w is RichText) {
        final String text = w.text.toPlainText();
        labelled = text.trim().isNotEmpty && !WidgetPaths.isIconGlyphs(text);
      } else if (w is Semantics) {
        labelled = w.properties.label?.trim().isNotEmpty ?? false;
      } else if (w is Tooltip) {
        labelled = w.message?.trim().isNotEmpty ?? false;
      } else if (w is Image) {
        labelled = w.semanticLabel?.trim().isNotEmpty ?? false;
      } else if (w is Icon) {
        labelled = w.semanticLabel?.trim().isNotEmpty ?? false;
      }
      if (!labelled) {
        e.visitChildren(visit);
      }
    }

    element.visitChildren(visit);
    return labelled;
  }

  /// The closest semantics node at or above [ro].
  static SemanticsNode? nearestNode(RenderObject? ro) {
    RenderObject? current = ro;
    while (current != null) {
      final SemanticsNode? node = current.debugSemantics;
      if (node != null) {
        return node;
      }
      current = current.parent;
    }
    return null;
  }

  /// The render view [ro] is painted in.
  static RenderView? viewOf(RenderObject? ro) {
    RenderObject? current = ro;
    while (current != null && current is! RenderView) {
      current = current.parent;
    }
    return current is RenderView ? current : null;
  }

  /// Text direction of the app content (looked up from the first text on screen).
  TextDirection get textDirection {
    final Iterable<Element> texts = find.byType(RichText).evaluate();
    if (texts.isEmpty) {
      return TextDirection.ltr;
    }
    return Directionality.maybeOf(texts.first) ?? TextDirection.ltr;
  }
}

/// A gesture widget whose tap is merged into a bigger semantics node.
class MergedGesture {
  /// Creates a record.
  const MergedGesture({
    required this.element,
    required this.rect,
    required this.node,
    required this.view,
    required this.hasLabel,
  });

  /// The `GestureDetector` / `InkWell` element.
  final Element element;

  /// Its rect, in logical pixels.
  final Rect rect;

  /// The node its tap ended up in.
  final SemanticsNode node;

  /// Its render view.
  final RenderView view;

  /// Whether something inside (or right around) it provides a label.
  final bool hasLabel;
}
