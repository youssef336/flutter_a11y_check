import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/bad_screen.dart';
import 'screens/good_screen.dart';

void main() => runApp(const ExampleApp());

/// Hosts a screen with English and Arabic (RTL) support.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, this.home});

  /// The screen to show. Defaults to a picker between the bad and the good screen.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'a11y check example',
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home ?? const PickerScreen(),
    );
  }
}

class PickerScreen extends StatelessWidget {
  const PickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('a11y check example')),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: const Text('Inaccessible checkout'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const BadScreen())),
          ),
          ListTile(
            title: const Text('Accessible checkout'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const GoodScreen())),
          ),
        ],
      ),
    );
  }
}
