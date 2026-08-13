import 'dart:io';

import 'package:excel/excel.dart';

import '../../../../core/errors/custom_exceptions.dart';
import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/dairy_sense_row.dart';

/// The single source of truth for the output workbook header names and
/// sheet name (matches the official `Milking Import Format.xlsx`).
const dairySenseSheetName = 'Sayfa1';
const dairySenseHeaders = <String>[
  'Date',
  'Session',
  'UnitNo',
  'CowNumber - in dairysense number-',
  'Milking Time -in seconds-',
  'Milk yield',
  'Conductivity',
  'temperature',
];

/// Date cells display as `dd/mm/yyyy` (e.g. `14/03/2001`).
final NumFormat _dateFormat = NumFormat.custom(formatCode: 'dd/mm/yyyy');

/// Milking-Time cells display as `hh:mm` (minutes:seconds in DairySense).
final NumFormat _milkingTimeFormat = CustomTimeNumFormat(formatCode: 'hh:mm');

/// Local data source that writes output workbooks to disk.
class DairySenseWriter {
  const DairySenseWriter();

  void write(List<DairySenseRow> rows, String path) =>
      writeDairySenseXlsx(rows, path);
}

/// Write [rows] to an XLSX workbook at [path] matching the official
/// `Milking Import Format.xlsx` (column order, cell types, number formats).
///
/// Synchronous so the pipeline can run in a single `Isolate.run` call.
void writeDairySenseXlsx(List<DairySenseRow> rows, String path) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.tables.keys.first;
  if (defaultSheet != dairySenseSheetName) {
    excel.rename(defaultSheet, dairySenseSheetName);
  }
  final sheet = excel[dairySenseSheetName];

  // Header row.
  for (var c = 0; c < dairySenseHeaders.length; c++) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      TextCellValue(dairySenseHeaders[c]),
    );
  }

  // Data rows (row 1 is the header).
  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    final rowIndex = r + 1;
    CellIndex index(int c) =>
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex);

    sheet.updateCell(
      index(0),
      _dateValue(row.date),
      cellStyle: CellStyle(numberFormat: _dateFormat),
    );
    sheet.updateCell(index(1), _numericOrText(row.session));
    sheet.updateCell(index(2), _numericOrText(row.unitNo));
    sheet.updateCell(index(3), IntCellValue(row.cowNumber));
    sheet.updateCell(
      index(4),
      _milkingTimeValue(row.milkingTime),
      cellStyle: CellStyle(numberFormat: _milkingTimeFormat),
    );
    sheet.updateCell(index(5), DoubleCellValue(row.milkYield));
    sheet.updateCell(index(6), IntCellValue(row.conductivity));
    sheet.updateCell(index(7), IntCellValue(row.temperature));
  }

  final bytes = excel.encode();
  if (bytes == null) {
    throw const OutputWriteError('workbook encoding produced no data');
  }
  try {
    File(path).writeAsBytesSync(bytes);
  } catch (e) {
    throw OutputWriteError('could not write the file ($e)');
  }
}

/// The report date as a real Excel Date value, or text when unparsable.
CellValue _dateValue(String date) {
  final dt = parseReportDate(date);
  if (dt == null) return TextCellValue(date);
  return DateCellValue(year: dt.year, month: dt.month, day: dt.day);
}

/// Milking time (total seconds) as a real Excel time value.
///
/// DairySense reads the displayed `hh:mm` as minutes:seconds, so a duration of
/// `totalSeconds` is remapped so that hours = minutes and minutes = seconds:
///   225 s -> 03:45, 282 s -> 04:42.
TimeCellValue _milkingTimeValue(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final remainingSeconds = totalSeconds % 60;
  return TimeCellValue(hour: minutes, minute: remainingSeconds);
}

/// Emit an integer cell when possible (Session/UnitNo are numeric in the
/// reference), otherwise keep the original text.
CellValue _numericOrText(String value) {
  final i = int.tryParse(value.trim());
  return i != null ? IntCellValue(i) : TextCellValue(value);
}
