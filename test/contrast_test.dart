import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_a11y_check/flutter_a11y_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contrast.ratio', () {
    test('black on white is 21:1, same color is 1:1, order does not matter', () {
      expect(Contrast.ratio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 1e-9));
      expect(Contrast.ratio(const Color(0xFF777777), const Color(0xFF777777)), 1);
      expect(
        Contrast.ratio(const Color(0xFFFFFFFF), const Color(0xFF767676)),
        Contrast.ratio(const Color(0xFF767676), const Color(0xFFFFFFFF)),
      );
    });

    test('known WCAG reference values', () {
      // #767676 is the classic "lightest grey that passes AA on white".
      expect(Contrast.ratio(const Color(0xFF767676), const Color(0xFFFFFFFF)), closeTo(4.54, 0.01));
      expect(Contrast.ratio(const Color(0xFF777777), const Color(0xFFFFFFFF)), closeTo(4.48, 0.01));
    });
  });

  test('hex formats opaque and translucent colors', () {
    expect(Contrast.hex(const Color(0xFF00FF7F)), '#00FF7F');
    expect(Contrast.hex(const Color(0x8000FF7F)), '#8000FF7F');
  });

  group('suggestForeground', () {
    test('darkens on a light background until the target is met', () {
      final Color? c = Contrast.suggestForeground(
        const Color(0xFFBDBDBD),
        const Color(0xFFFFFFFF),
        4.5,
      );
      expect(c, isNotNull);
      expect(Contrast.ratio(c!, const Color(0xFFFFFFFF)), greaterThanOrEqualTo(4.5));
      expect(Contrast.luminance(c), lessThan(Contrast.luminance(const Color(0xFFBDBDBD))));
    });

    test('lightens on a dark background', () {
      final Color? c = Contrast.suggestForeground(
        const Color(0xFF333333),
        const Color(0xFF000000),
        7,
      );
      expect(Contrast.ratio(c!, const Color(0xFF000000)), greaterThanOrEqualTo(7));
    });

    test('returns null when nothing can reach the target', () {
      expect(
        Contrast.suggestForeground(const Color(0xFF777777), const Color(0xFF777777), 22),
        isNull,
      );
    });
  });

  group('histogram and sample', () {
    // 10x10 white image with a 4x4 black square at (3,3).
    ByteData image() {
      final ByteData data = ByteData(10 * 10 * 4);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 10; x++) {
          final bool ink = x >= 3 && x < 7 && y >= 3 && y < 7;
          data.setUint32((y * 10 + x) * 4, ink ? 0x000000FF : 0xFFFFFFFF);
        }
      }
      return data;
    }

    test('counts colors inside a rect and can exclude an inner rect', () {
      final Map<Color, int> all = Contrast.histogram(
        image(),
        10,
        10,
        const Rect.fromLTWH(0, 0, 10, 10),
      );
      expect(all[const Color(0xFF000000)], 16);
      expect(all[const Color(0xFFFFFFFF)], 84);
      final Map<Color, int> ring = Contrast.histogram(
        image(),
        10,
        10,
        const Rect.fromLTWH(1, 1, 8, 8),
        exclude: const Rect.fromLTWH(3, 3, 4, 4),
      );
      expect(ring.keys, <Color>[const Color(0xFFFFFFFF)]);
    });

    test('rects outside the image give an empty histogram', () {
      expect(Contrast.histogram(image(), 10, 10, const Rect.fromLTWH(20, 20, 5, 5)), isEmpty);
    });

    test('sample names the background from the ring around the text', () {
      final ByteData data = image();
      final ContrastSample s = Contrast.sample(
        Contrast.histogram(data, 10, 10, const Rect.fromLTWH(1, 1, 8, 8)),
        ring: Contrast.histogram(
          data,
          10,
          10,
          const Rect.fromLTWH(1, 1, 8, 8),
          exclude: const Rect.fromLTWH(3, 3, 4, 4),
        ),
      )!;
      expect(s.foreground, const Color(0xFF000000));
      expect(s.background, const Color(0xFFFFFFFF));
      expect(s.ratio, closeTo(21, 1e-9));
    });

    test('a single color is its own foreground and background', () {
      final ContrastSample s = Contrast.sample(<Color, int>{const Color(0xFF123456): 9})!;
      expect(s.ratio, 1);
      expect(Contrast.sample(<Color, int>{}), isNull);
    });
  });

  group('ContrastLevel', () {
    test('WCAG large-text thresholds', () {
      expect(ContrastLevel.aa.requiredRatio(14, bold: false), 4.5);
      expect(ContrastLevel.aa.requiredRatio(24, bold: false), 3);
      expect(ContrastLevel.aa.requiredRatio(18, bold: true), 4.5);
      expect(ContrastLevel.aa.requiredRatio(19, bold: true), 3);
      expect(ContrastLevel.aaa.requiredRatio(14, bold: false), 7);
      expect(ContrastLevel.aaa.requiredRatio(30, bold: false), 4.5);
    });
  });
}
