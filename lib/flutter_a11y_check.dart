/// One-line accessibility audit for Flutter widget tests.
///
/// ```dart
/// testWidgets('login is accessible', (tester) async {
///   await tester.pumpWidget(const MyApp());
///   await expectAccessible(tester);
/// });
/// ```
library;

export 'src/audit.dart' show auditAccessibility, expectAccessible;
export 'src/config.dart' show A11yConfig, ContrastLevel;
export 'src/contrast.dart' show Contrast, ContrastSample;
export 'src/finding.dart' show A11yFinding, A11yRule, A11ySeverity;
export 'src/ignore.dart' show A11yIgnore;
export 'src/report.dart' show A11yReport;
