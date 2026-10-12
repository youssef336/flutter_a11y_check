import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'sample_image.dart';

/// A checkout screen with one example of every problem the audit looks for.
class BadScreen extends StatelessWidget {
  const BadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        actions: <Widget>[
          // missing-label: no tooltip.
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // text-scale: fixed Row with no Expanded overflows at 200%.
          const Row(
            children: <Widget>[
              Text('Total amount due this month'),
              SizedBox(width: 16),
              Text('EGP 1,250.00'),
            ],
          ),
          const SizedBox(height: 8),
          // text-scale: one-line text gets cut off at 200%.
          const SizedBox(
            width: 600,
            child: Text(
              'Your subscription renews automatically',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // text-scale: ignores the font-size setting.
          const Text('Build 1.0.3', textScaler: TextScaler.noScaling),
          const SizedBox(height: 8),
          // contrast: light grey on white.
          const Text('Prices include VAT', style: TextStyle(color: Color(0xFFBDBDBD))),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              // image-label: no semanticLabel, not decorative.
              Image.memory(samplePng, width: 48, height: 48),
              const SizedBox(width: 16),
              // tap-target + missing-label: 24x24 gesture detector around an icon.
              SizedBox(
                width: 24,
                height: 24,
                child: GestureDetector(onTap: () {}, child: const Icon(Icons.close, size: 24)),
              ),
              const SizedBox(width: 16),
              // tap-target: shrink-wrapped text button.
              TextButton(
                style: TextButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(32, 24),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () {},
                child: const Text('Skip'),
              ),
            ],
          ),
          // duplicate-label: three buttons all called "Remove".
          for (final String item in <String>['Coffee', 'Tea', 'Cake'])
            Row(
              children: <Widget>[
                Text(item),
                const Spacer(),
                TextButton(onPressed: () {}, child: const Text('Remove')),
              ],
            ),
          // generic-label + focus-order: "Click here" is read before "Back" although it is
          // to the right of it.
          Row(
            children: <Widget>[
              Semantics(
                container: true,
                sortKey: const OrdinalSortKey(2),
                child: TextButton(onPressed: () {}, child: const Text('Back')),
              ),
              const SizedBox(width: 16),
              Semantics(
                container: true,
                sortKey: const OrdinalSortKey(1),
                child: ElevatedButton(onPressed: () {}, child: const Text('Click here')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
