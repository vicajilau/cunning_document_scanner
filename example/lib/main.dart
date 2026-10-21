import 'package:cunning_document_scanner_example/example_strings.dart';
import 'package:cunning_document_scanner_example/scanner_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // No `locale` is set, so Flutter follows the language iOS resolves for the app, the same one
    // Apple's scanner screens and the plugin's own strings use.
    return MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: [
        for (final code in supportedLanguageCodes) Locale(code),
      ],
      home: const ScannerHomeScreen(),
    );
  }
}
