import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../config.dart';
import '../context.dart';
import '../contrast.dart';
import '../finding.dart';
import '../format.dart';
import '../widget_path.dart';

/// Text whose rendered contrast is below the configured WCAG level.
///
/// Like `textContrastGuideline` in `flutter_test` it reads the pixels of the rendered frame, but it
/// starts from every visible piece of text (not only text whose label matches a semantics node),
/// uses the WCAG size thresholds (24px, or 18.66px bold, after text scaling), and reports the
/// measured colors plus a nearby color that would pass.
Future<List<A11yFinding>> checkContrast(AuditContext ctx) async {
  final List<A11yFinding> findings = <A11yFinding>[];
  if (ctx.config.contrast == ContrastLevel.off) {
    return findings;
  }
  final List<Element> texts = find.byType(RichText).hitTestable().evaluate().toList();
  if (texts.isEmpty) {
    return findings;
  }
  final Map<RenderView, _Frame?> frames = <RenderView, _Frame?>{};
  try {
    for (final Element element in texts) {
      final RichText widget = element.widget as RichText;
      final RenderObject? ro = element.renderObject;
      if (ro is! RenderParagraph || !ro.hasSize || ro.size.isEmpty) {
        continue;
      }
      final String text = widget.text.toPlainText();
      if (text.trim().isEmpty || WidgetPaths.isIconText(element, text) || _isDisabled(ro)) {
        continue;
      }
      final RenderView? view = AuditContext.viewOf(ro);
      if (view == null) {
        continue;
      }
      if (!frames.containsKey(view)) {
        frames[view] = await _capture(ctx.tester, view);
      }
      final _Frame? frame = frames[view];
      if (frame == null) {
        continue;
      }
      final Rect textRect = MatrixUtils.transformRect(
        ro.getTransformTo(null),
        Offset.zero & ro.size,
      );
      final Map<Color, int> all = Contrast.histogram(
        frame.bytes,
        frame.width,
        frame.height,
        textRect.inflate(4),
      );
      final Map<Color, int> ring = Contrast.histogram(
        frame.bytes,
        frame.width,
        frame.height,
        textRect.inflate(4),
        exclude: textRect,
      );
      final ContrastSample? sample = Contrast.sample(all, ring: ring.isEmpty ? null : ring);
      if (sample == null) {
        continue;
      }
      final TextStyle style = widget.text.style ?? const TextStyle();
      final double baseSize = style.fontSize ?? 14;
      final double size = widget.textScaler.scale(baseSize);
      final bool bold = (style.fontWeight ?? FontWeight.normal).value >= FontWeight.w700.value;
      final double required = ctx.config.contrast.requiredRatio(size, bold: bold);
      final double ratio = sample.ratio;
      if (ratio + 0.01 >= required) {
        continue;
      }
      final Element subject = WidgetPaths.textWidgetOf(element);
      final WidgetDescription where = ctx.describeElement(subject);
      final Color? better = Contrast.suggestForeground(
        sample.foreground,
        sample.background,
        required,
      );
      final bool large = ContrastLevel.isLargeText(size, bold: bold);
      final String level = ctx.config.contrast.name.toUpperCase();
      findings.add(
        ctx.finding(
          rule: A11yRule.contrast,
          message:
              '"${clip(text)}" has contrast ${ratio.toStringAsFixed(2)}:1 '
              '(${Contrast.hex(sample.foreground)} on ${Contrast.hex(sample.background)}); '
              'WCAG $level needs ${fmtNum(required)}:1 for ${large ? 'large' : 'normal'} text '
              '(${fmtNum(size)}px${bold ? ' bold' : ''}).',
          suggestion: better == null
              ? 'Change the background so the text can reach ${fmtNum(required)}:1.'
              : 'Use ${Contrast.hex(better)} (or darker/stronger) for the text, or change the '
                    'background${large ? '' : ', or make the text large (24px+, or 18.66px+ bold)'}.',
          where: where,
          label: text,
          rect: textRect,
          data: <String, Object?>{
            'ratio': double.parse(ratio.toStringAsFixed(2)),
            'required': required,
            'foreground': Contrast.hex(sample.foreground),
            'background': Contrast.hex(sample.background),
            'fontSize': round1(size),
            'bold': bold,
            if (better != null) 'suggestedForeground': Contrast.hex(better),
          },
          dedupeKey: '${identityHashCode(element)}',
        ),
      );
    }
  } finally {
    for (final _Frame? frame in frames.values) {
      frame?.image.dispose();
    }
  }
  return findings;
}

class _Frame {
  _Frame(this.image, this.bytes);
  final ui.Image image;
  final ByteData bytes;
  int get width => image.width;
  int get height => image.height;
}

Future<_Frame?> _capture(WidgetTester tester, RenderView view) async {
  final ContainerLayer? layer = view.debugLayer;
  if (layer is! OffsetLayer) {
    return null;
  }
  return tester.binding.runAsync<_Frame?>(() async {
    // Logical-pixel image, so render box coordinates map 1:1 onto pixels.
    final ui.Image image = await layer.toImage(
      view.paintBounds,
      pixelRatio: 1 / view.flutterView.devicePixelRatio,
    );
    final ByteData? bytes = await image.toByteData();
    if (bytes == null) {
      image.dispose();
      return null;
    }
    return _Frame(image, bytes);
  });
}

bool _isDisabled(RenderObject ro) {
  RenderObject? current = ro;
  while (current != null) {
    final SemanticsNode? node = current.debugSemantics;
    if (node != null) {
      return node.getSemanticsData().flagsCollection.isEnabled == ui.Tristate.isFalse;
    }
    current = current.parent;
  }
  return false;
}
