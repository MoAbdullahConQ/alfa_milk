import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'dart:io';

import '../../../../core/errors/custom_exceptions.dart';
import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/alpro_record.dart';
import '../../domain/entities/alpro_report.dart';

/// Local data source that parses an Alpro HTML report file.
class AlproParser {
  const AlproParser();

  AlproReport parseFile(String htmlPath) =>
      parseAlproReport(File(htmlPath).readAsStringSync());
}

/// Parse an Alpro HTML report into an [AlproReport].
///
/// See `contracts/file-formats.md` §1 for the structure and header rules.
AlproReport parseAlproReport(String htmlString) {
  final document = html.parse(htmlString);
  final warnings = <String>[];

  final report = _locateReportTable(document, warnings);
  if (report == null) {
    throw const AlproParseError('no data table containing cow numbers found');
  }

  final date = _extractDate(document);
  final session = _extractSession(document);
  if (date == null) {
    warnings.add('Date not found; Date column left out of output.');
  }
  if (session == null) {
    warnings.add('Session not found; Session column left out of output.');
  }

  final records = <AlproRecord>[];
  for (final row in report.tableRows) {
    final cells = row.children
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (cells.isEmpty) continue;

    final values = <String, String>{};
    for (final entry in report.columns.entries) {
      final index = entry.value;
      if (index < cells.length) values[entry.key] = cells[index];
    }

    final cowRaw = values['cowno'] ?? '';
    final cowNumber = normalizeCowNumber(cowRaw);
    if (cowNumber == null) {
      throw const AlproParseError(
          'a data row has an unparsable cow number and could not be read');
    }

    final yieldRaw =
        (values['milkyield'] ?? values['milyield'] ?? values['milyeild'] ?? '')
            .trim();
    final milkDur = (values['milkdur'] ?? '').trim();

    // Only a truly empty cell means "no data" → skip. A non-numeric yield
    // (e.g. "-") and a non-time duration (e.g. "-") mean the cow was not
    // milked that session; they are kept and exported as 0 by the row builder.
    if (yieldRaw.isEmpty || milkDur.isEmpty) {
      warnings.add('Skipped cow $cowNumber: missing Milk Yield or Milk Dur.');
      continue;
    }

    final double milkYield = double.tryParse(yieldRaw) ?? 0.0;

    records.add(AlproRecord(
      cowNumber: cowNumber,
      unitNo: values['mpcaddress'] ?? '',
      milkYield: milkYield,
      milkDur: milkDur,
    ));
  }

  return AlproReport(
    date: date ?? '',
    session: session ?? '',
    records: records,
    warnings: warnings,
  );
}

/// Locate the data table whose header row contains the `cowno` column.
_ReportTable? _locateReportTable(dom.Document document, List<String> warnings) {
  for (final table in document.querySelectorAll('table')) {
    final rows = table.querySelectorAll('tr');
    for (final row in rows) {
      final cells = row.children.map((c) => c.text.trim()).toList();
      final normalized =
          cells.map((c) => normalizeHeader(c)).toList(growable: false);

      final cowIndex = normalized.indexWhere((n) => _headerMatches(n, 'cowno'));
      if (cowIndex == -1) continue;

      final columns = <String, int>{};
      int? mpcIndex;
      int? yieldIndex;
      int? durIndex;
      for (var i = 0; i < normalized.length; i++) {
        final n = normalized[i];
        if (mpcIndex == null && _headerMatches(n, 'mpcaddress')) mpcIndex = i;
        if (yieldIndex == null &&
            (_headerMatches(n, 'milyield') ||
                _headerMatches(n, 'milyeild') ||
                _headerMatches(n, 'milkyield'))) {
          yieldIndex = i;
        }
        if (durIndex == null && _headerMatches(n, 'milkdur')) durIndex = i;
      }

      if (yieldIndex == null) {
        throw const AlproParseError('required column "Milk Yield" not found');
      }
      if (durIndex == null) {
        throw const AlproParseError('required column "Milk Dur." not found');
      }

      columns['cowno'] = cowIndex;
      columns['mpcaddress'] = mpcIndex ?? 0;
      columns['milyield'] = yieldIndex;
      columns['milkdur'] = durIndex;

      final dataRows = rows.skip(rows.indexOf(row) + 1);
      return _ReportTable(columns: columns, tableRows: dataRows.toList());
    }
  }
  return null;
}

/// Whether a normalized header matches the expected name.
///
/// Tolerates a trailing sort-indicator digit (e.g. "Cow No." rendered with an
/// ascending/descending arrow and its order number renders as `cowno1`, which
/// still identifies the cow-number column). Only applies to known required
/// column names, never to a bare `milk`/`cow` fallback (contracts §1).
bool _headerMatches(String normalized, String name) =>
    normalized == name || normalized.startsWith(name);

/// Extract the report Date: first via a `Date` label/value pair, then by
/// scanning for a date token in the document text (handles the real Alpro
/// format, e.g. `26.08.08` in "ALPRO Time: 0:15  26.08.08").
String? _extractDate(dom.Document document) =>
    _extractLabel(document, 'date') ?? _extractPatternDate(document);

final _isoDatePattern = RegExp(r'\b\d{4}[-/.]\d{1,2}[-/.]\d{1,2}\b');
final _shortDatePattern = RegExp(r'\b\d{1,2}[./]\d{1,2}[./]\d{2}\b');

String? _extractPatternDate(dom.Document document) {
  final text = document.body?.text ?? '';
  return _isoDatePattern.firstMatch(text)?.group(0) ??
      _shortDatePattern.firstMatch(text)?.group(0);
}

/// Extract the report Session: first via a `Session` label/value pair, then by
/// reading the active session number from "Session N" (e.g. the report title
/// "ID Performance Details: Today, Session 1").
String? _extractSession(dom.Document document) =>
    _extractLabel(document, 'session') ?? _extractPatternSession(document);

final _sessionPattern = RegExp(r'Session\s+(\d+)');

String? _extractPatternSession(dom.Document document) {
  final text = document.body?.text ?? '';
  return _sessionPattern.firstMatch(text)?.group(1);
}

/// Find a label (`date`/`session`) and return the value that follows it.
String? _extractLabel(dom.Document document, String label) {
  for (final element in document.body?.querySelectorAll('td,th,span,div') ??
      <dom.Element>[]) {
    final text = element.text.trim().toLowerCase();
    if (text != label) continue;

    final parent = element.parent;
    if (parent == null) continue;
    final siblings = parent.children.where((c) => c != element).toList();
    for (final sibling in siblings) {
      final value = sibling.text.trim();
      if (value.isNotEmpty && value.toLowerCase() != label) return value;
    }
  }
  return null;
}

class _ReportTable {
  _ReportTable({required this.columns, required this.tableRows});

  final Map<String, int> columns;
  final List<dom.Element> tableRows;
}
