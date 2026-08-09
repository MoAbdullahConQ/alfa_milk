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

  final date = _extractLabel(document, 'date');
  final session = _extractLabel(document, 'session');
  if (date == null) {
    warnings.add('Date label not found; Date column left out of output.');
  }
  if (session == null) {
    warnings.add('Session label not found; Session column left out of output.');
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
        values['milkyield'] ?? values['milyield'] ?? values['milyeild'];
    final milkDur = values['milkdur'];
    final double? milkYield = double.tryParse((yieldRaw ?? '').trim());

    if (milkYield == null || milkDur == null || durationToSeconds(milkDur) == null) {
      warnings.add(
          'Skipped cow $cowNumber: missing or invalid Milk Yield or Milk Dur.');
      continue;
    }

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

      final cowIndex = normalized.indexOf('cowno');
      if (cowIndex == -1) continue;

      final columns = <String, int>{};
      int? mpcIndex;
      int? yieldIndex;
      int? durIndex;
      for (var i = 0; i < normalized.length; i++) {
        final n = normalized[i];
        if (n == 'mpcaddress' && mpcIndex == null) mpcIndex = i;
        if ((n == 'milyield' || n == 'milyeild' || n == 'milkyield') &&
            yieldIndex == null) {
          yieldIndex = i;
        }
        if (n == 'milkdur' && durIndex == null) durIndex = i;
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
