import 'dart:io';

import 'package:excel/excel.dart';

import '../../../core/errors/custom_exceptions.dart';
import '../../../core/utils/app_utils.dart';

/// Result of loading cow numbers from an XLSX workbook (contracts §2).
class CowListLoadResult {
  const CowListLoadResult({
    required this.cowNumbers,
    required this.warnings,
    required this.usedFallback,
  });

  /// Deduplicated cow numbers, in first-seen order.
  final List<int> cowNumbers;

  /// Non-integer cells skipped from the chosen column, as warnings.
  final List<String> warnings;

  /// True when no "Cow Number"-style header matched and the first int column
  /// was used instead (FR-004). The UI informs the user when this happens.
  final bool usedFallback;
}

/// Reads cow numbers from a cow-list XLSX file.
class CowListLoader {
  const CowListLoader();

  CowListLoadResult load(String path) => loadCowListFromXlsx(path);
}

/// Detect the cow-number column by header, else fall back to the first column
/// containing a valid int. Skip blanks, warn on non-integers, deduplicate.
CowListLoadResult loadCowListFromXlsx(String path) {
  final Excel excel;
  try {
    final bytes = File(path).readAsBytesSync();
    excel = Excel.decodeBytes(bytes);
  } catch (e) {
    throw CowListError('could not open the workbook ($e)');
  }

  final Sheet sheet;
  try {
    sheet = excel.tables.values.firstWhere((s) => s.rows.isNotEmpty);
  } catch (_) {
    throw const CowListError('the workbook contains no data');
  }

  final rows = sheet.rows;

  // First non-empty row = headers (contracts/file-formats.md §2).
  var headerIndex = -1;
  for (var r = 0; r < rows.length; r++) {
    if (rows[r].any((c) => _cellToString(c).trim().isNotEmpty)) {
      headerIndex = r;
      break;
    }
  }
  if (headerIndex == -1) {
    throw const CowListError('the workbook contains no data');
  }

  final headers = rows[headerIndex].map(_cellToString).toList();
  final normalized = headers.map(normalizeHeader).toList();

  // 1. First header starting with `cownum` or equal to `cow` wins.
  var chosenColumn = -1;
  for (var c = 0; c < normalized.length; c++) {
    final h = normalized[c];
    if (h.startsWith('cownum') || h == 'cow') {
      chosenColumn = c;
      break;
    }
  }
  final usedFallback = chosenColumn == -1;

  // 2. Fallback: first column holding at least one valid int (FR-004).
  if (chosenColumn == -1) {
    for (var c = 0; c < headers.length; c++) {
      for (var r = headerIndex + 1; r < rows.length; r++) {
        final row = rows[r];
        if (c < row.length &&
            normalizeCowNumber(_cellToString(row[c])) != null) {
          chosenColumn = c;
          break;
        }
      }
      if (chosenColumn != -1) break;
    }
  }

  if (chosenColumn == -1) {
    throw const CowListError('no cow numbers found');
  }

  final cowNumbers = <int>[];
  final seen = <int>{};
  final warnings = <String>[];

  for (var r = headerIndex + 1; r < rows.length; r++) {
    final row = rows[r];
    if (chosenColumn >= row.length) continue;
    final raw = _cellToString(row[chosenColumn]);
    if (raw.trim().isEmpty) continue; // skip blank rows
    final num = normalizeCowNumber(raw);
    if (num == null) {
      warnings.add('row ${r + 1}: "$raw" is not a valid cow number');
      continue;
    }
    if (seen.add(num)) {
      cowNumbers.add(num);
    }
  }

  if (cowNumbers.isEmpty) {
    throw const CowListError('no cow numbers found');
  }

  return CowListLoadResult(
    cowNumbers: cowNumbers,
    warnings: warnings,
    usedFallback: usedFallback,
  );
}

/// Convert an excel v4 [CellValue] to its plain string form.
String _cellToString(Data? data) {
  final value = data?.value;
  if (value == null) return '';
  if (value is TextCellValue) return value.value.text ?? '';
  if (value is IntCellValue) return value.value.toString();
  if (value is DoubleCellValue) return value.value.toString();
  if (value is BoolCellValue) return value.value.toString();
  if (value is DateTimeCellValue) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    ).toIso8601String();
  }
  if (value is DateCellValue) {
    return DateTime(value.year, value.month, value.day).toIso8601String();
  }
  return value.toString();
}
