import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'finding.dart';
import 'format.dart';

/// The result of an audit: every finding, plus what was run.
@immutable
class A11yReport {
  /// Creates a report.
  const A11yReport({
    required this.findings,
    this.variants = const <String>[],
    this.ignored = 0,
    this.notes = const <String>[],
    this.failOn = A11ySeverity.warning,
  });

  /// Findings, most severe first.
  final List<A11yFinding> findings;

  /// The runs that were audited, e.g. `100%`, `200%`, `100% · ar (rtl)`.
  final List<String> variants;

  /// How many findings were silenced by ignores.
  final int ignored;

  /// Things worth knowing that are not findings (e.g. "the RTL run stayed LTR").
  final List<String> notes;

  /// The severity at which [passed] becomes false.
  final A11ySeverity failOn;

  /// Findings with severity [A11ySeverity.error].
  List<A11yFinding> get errors => _of(A11ySeverity.error);

  /// Findings with severity [A11ySeverity.warning].
  List<A11yFinding> get warnings => _of(A11ySeverity.warning);

  /// Findings with severity [A11ySeverity.info].
  List<A11yFinding> get infos => _of(A11ySeverity.info);

  List<A11yFinding> _of(A11ySeverity s) =>
      findings.where((A11yFinding f) => f.severity == s).toList();

  /// Findings of [rule].
  List<A11yFinding> byRule(A11yRule rule) =>
      findings.where((A11yFinding f) => f.rule == rule).toList();

  /// Whether no finding reaches [failOn].
  bool get passed => !findings.any((A11yFinding f) => f.severity.isAtLeast(failOn));

  String get _counts {
    String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
    return '${plural(errors.length, 'error')}, ${plural(warnings.length, 'warning')}, '
        '${infos.length} info';
  }

  /// Plain-text report for the console. With [color], uses ANSI colors.
  String toText({bool color = true}) {
    String paint(String text, String code) => color ? '\x1B[${code}m$text\x1B[0m' : text;
    String dim(String text) => paint(text, '2');
    String tag(A11ySeverity s) {
      switch (s) {
        case A11ySeverity.error:
          return paint('ERROR  ', '1;31');
        case A11ySeverity.warning:
          return paint('WARN   ', '1;33');
        case A11ySeverity.info:
          return paint('INFO   ', '1;36');
      }
    }

    final StringBuffer out = StringBuffer();
    final String status = passed ? paint('PASSED', '1;32') : paint('FAILED', '1;31');
    out.writeln('Accessibility audit $status: $_counts');
    final List<String> meta = <String>[
      if (variants.isNotEmpty) 'runs: ${variants.join(', ')}',
      if (ignored > 0) '$ignored ignored',
    ];
    if (meta.isNotEmpty) {
      out.writeln(dim(meta.join(' | ')));
    }
    for (final A11yFinding f in findings) {
      out.writeln();
      out.writeln('${tag(f.severity)}${paint(f.rule.id, '1')}  ${f.message}');
      if (f.path != null) {
        out.writeln('       ${dim('where')} ${f.path}');
      }
      final String? place = _place(f);
      if (place != null) {
        out.writeln('       ${dim('rect ')} $place');
      }
      final Object? paths = f.data['paths'];
      if (paths is List<Object?> && paths.length > 1) {
        for (final Object? p in paths.skip(1)) {
          out.writeln('       ${dim('also ')} $p');
        }
      }
      out.writeln('       ${dim('fix  ')} ${paint(f.suggestion, '32')}');
    }
    for (final String note in notes) {
      out.writeln();
      out.writeln('${dim('note')}   $note');
    }
    return out.toString().trimRight();
  }

  /// Markdown report, e.g. for a PR comment or a CI artifact.
  String toMarkdown({String title = 'Accessibility audit'}) {
    String cell(String text) => text.replaceAll('|', r'\|').replaceAll('\n', ' ');
    const Map<A11ySeverity, String> icon = <A11ySeverity, String>{
      A11ySeverity.error: '🔴 error',
      A11ySeverity.warning: '🟡 warning',
      A11ySeverity.info: '🔵 info',
    };
    final StringBuffer out = StringBuffer()
      ..writeln('## $title: ${passed ? 'passed' : 'failed'}')
      ..writeln()
      ..writeln(
        '**$_counts**${ignored > 0 ? ' · $ignored ignored' : ''}'
        '${variants.isEmpty ? '' : ' · runs: ${variants.join(', ')}'}',
      );
    if (findings.isEmpty) {
      out
        ..writeln()
        ..writeln('No accessibility issues found.');
    } else {
      out
        ..writeln()
        ..writeln('| Severity | Rule | Where | Issue | Fix |')
        ..writeln('|---|---|---|---|---|');
      for (final A11yFinding f in findings) {
        final String? place = _place(f);
        final String where = <String>[
          if (f.path != null) '`${cell(f.path!)}`',
          ?place,
        ].join('<br>');
        out.writeln(
          '| ${icon[f.severity]} | `${f.rule.id}` | $where | ${cell(f.message)} | '
          '${cell(f.suggestion)} |',
        );
      }
    }
    if (notes.isNotEmpty) {
      out.writeln();
      for (final String note in notes) {
        out.writeln('> $note');
      }
    }
    return out.toString().trimRight();
  }

  /// JSON-friendly map.
  Map<String, Object?> toJson() => <String, Object?>{
    'passed': passed,
    'failOn': failOn.name,
    'summary': <String, int>{
      'error': errors.length,
      'warning': warnings.length,
      'info': infos.length,
      'ignored': ignored,
    },
    'variants': variants,
    'notes': notes,
    'findings': findings.map((A11yFinding f) => f.toJson()).toList(),
  };

  /// Indented JSON string.
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static String? _place(A11yFinding f) {
    final List<String> parts = <String>[
      if (f.rect != null)
        '(${fmtNum(round1(f.rect!.left))}, ${fmtNum(round1(f.rect!.top))}) '
            '${fmtNum(round1(f.rect!.width))}x${fmtNum(round1(f.rect!.height))}',
      if (f.variant != null) 'at ${f.variant}',
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  @override
  String toString() => toText(color: false);
}
