import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// WCAG contrast math and the screenshot sampling used by the contrast rule.
///
/// The sampling mirrors `textContrastGuideline` in `flutter_test`: take the pixels around the
/// text, split them into "light" and "dark" by HSL lightness, and use the most common color of
/// each half. On top of that it works out which of the two is the background (the color that
/// dominates the ring just outside the text) so the report can say "X on Y".
abstract final class Contrast {
  /// WCAG relative luminance of [color] (alpha ignored).
  static double luminance(Color color) => color.computeLuminance();

  /// WCAG contrast ratio between two colors, from 1.0 to 21.0. Order does not matter.
  static double ratio(Color a, Color b) {
    final double la = luminance(a);
    final double lb = luminance(b);
    final double light = la > lb ? la : lb;
    final double dark = la > lb ? lb : la;
    return (light + 0.05) / (dark + 0.05);
  }

  /// `#RRGGBB`, or `#AARRGGBB` when not opaque.
  static String hex(Color color) {
    final int argb = color.toARGB32();
    final String rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    final int alpha = argb >> 24 & 0xFF;
    if (alpha == 0xFF) {
      return '#$rgb';
    }
    return '#${alpha.toRadixString(16).padLeft(2, '0').toUpperCase()}$rgb';
  }

  /// The closest color to [foreground] (same hue and saturation, different lightness) that
  /// reaches [target] against [background]. Returns null if none does.
  static Color? suggestForeground(Color foreground, Color background, double target) {
    final HSLColor hsl = HSLColor.fromColor(foreground.withAlpha(0xFF));
    final bool darken = luminance(background) > 0.18;
    for (final bool towardsBlack in <bool>[darken, !darken]) {
      for (var step = 1; step <= 100; step++) {
        final double delta = step / 100;
        final double lightness = towardsBlack ? hsl.lightness - delta : hsl.lightness + delta;
        if (lightness < 0 || lightness > 1) {
          break;
        }
        final Color candidate = hsl.withLightness(lightness).toColor();
        if (ratio(candidate, background) >= target) {
          return candidate;
        }
      }
    }
    return null;
  }

  /// Counts the colors of the pixels of an RGBA [data] image ([width] x [height]) inside
  /// [rect], skipping pixels inside [exclude].
  static Map<Color, int> histogram(
    ByteData data,
    int width,
    int height,
    Rect rect, {
    Rect? exclude,
  }) {
    final Rect bounds = rect.intersect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    final counts = <int, int>{};
    if (bounds.width <= 0 || bounds.height <= 0) {
      return <Color, int>{};
    }
    final int left = bounds.left.floor();
    final int right = bounds.right.ceil();
    final int top = bounds.top.floor();
    final int bottom = bounds.bottom.ceil();
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        if (exclude != null && exclude.contains(Offset(x + 0.5, y + 0.5))) {
          continue;
        }
        final int rgba = data.getUint32((y * width + x) * 4);
        counts.update(rgba, (int c) => c + 1, ifAbsent: () => 1);
      }
    }
    return counts.map<Color, int>((int rgba, int count) {
      final int argb = (rgba << 24 | rgba >> 8) & 0xFFFFFFFF;
      return MapEntry<Color, int>(Color(argb), count);
    });
  }

  /// Picks the representative light and dark colors of [colors] (same method as
  /// `flutter_test`), then names the background using [ring] (pixels just around the text).
  static ContrastSample? sample(Map<Color, int> colors, {Map<Color, int>? ring}) {
    if (colors.isEmpty) {
      return null;
    }
    var total = 0.0;
    var count = 0;
    for (final MapEntry<Color, int> e in colors.entries) {
      total += HSLColor.fromColor(e.key).lightness * e.value;
      count += e.value;
    }
    final double average = total / count;
    MapEntry<Color, int>? light;
    MapEntry<Color, int>? dark;
    for (final MapEntry<Color, int> e in colors.entries) {
      if (HSLColor.fromColor(e.key).lightness <= average) {
        if (e.value > (dark?.value ?? 0)) {
          dark = e;
        }
      } else if (e.value > (light?.value ?? 0)) {
        light = e;
      }
    }
    final Color lightColor = light?.key ?? dark!.key;
    final Color darkColor = dark?.key ?? light!.key;
    final Map<Color, int> around = ring ?? colors;
    final int lightAround = around[lightColor] ?? 0;
    final int darkAround = around[darkColor] ?? 0;
    final bool lightIsBackground = lightAround >= darkAround;
    return ContrastSample(
      foreground: lightIsBackground ? darkColor : lightColor,
      background: lightIsBackground ? lightColor : darkColor,
    );
  }
}

/// The two colors measured for a piece of text.
class ContrastSample {
  /// Creates a sample.
  const ContrastSample({required this.foreground, required this.background});

  /// The text color as rendered.
  final Color foreground;

  /// The color behind the text as rendered.
  final Color background;

  /// WCAG ratio between [foreground] and [background].
  double get ratio => Contrast.ratio(foreground, background);
}
