/// `48` for 48.0, `40.5` for 40.5.
String fmtNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Rounds to one decimal, for JSON.
double round1(double v) => (v * 10).roundToDouble() / 10;

/// Shortens [text] to [max] characters with an ellipsis, on one line.
String clip(String text, [int max = 40]) {
  final String oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length <= max ? oneLine : '${oneLine.substring(0, max - 1)}…';
}
