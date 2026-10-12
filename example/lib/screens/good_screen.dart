import 'package:flutter/material.dart';

import 'sample_image.dart';

/// The same checkout screen, fixed.
class GoodScreen extends StatelessWidget {
  const GoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        actions: <Widget>[
          IconButton(tooltip: 'Share order', icon: const Icon(Icons.share), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Row(
            children: <Widget>[
              Expanded(child: Text('Total amount due this month')),
              SizedBox(width: 16),
              Flexible(child: Text('EGP 1,250.00')),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Your subscription renews automatically'),
          const Text('Build 1.0.3'),
          const SizedBox(height: 8),
          const Text('Prices include VAT', style: TextStyle(color: Color(0xFF616161))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Image.memory(samplePng, width: 48, height: 48, semanticLabel: 'Order summary'),
              IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () {}),
              TextButton(onPressed: () {}, child: const Text('Skip')),
            ],
          ),
          for (final String item in <String>['Coffee', 'Tea', 'Cake'])
            Row(
              children: <Widget>[
                Expanded(child: Text(item)),
                TextButton(onPressed: () {}, child: Text('Remove $item')),
              ],
            ),
          Wrap(
            spacing: 16,
            children: <Widget>[
              TextButton(onPressed: () {}, child: const Text('Back')),
              ElevatedButton(onPressed: () {}, child: const Text('Pay now')),
            ],
          ),
        ],
      ),
    );
  }
}
