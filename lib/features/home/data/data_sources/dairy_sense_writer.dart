import 'dart:io';

import 'package:excel/excel.dart';

import '../../../../core/errors/custom_exceptions.dart';
import '../../domain/entities/dairy_sense_row.dart';

/// The single source of truth for the output workbook header names and
/// sheet name (contracts/file-formats.md §3). Adjust here only if the real
/// `dairy_sense_template.xlsx` differs (T021).
const dairySenseSheetName = 'DairySense';
const dairySenseHeaders = <String>[
  'Date',
  'Session',
  'UnitNo',
  'CowNumber',
  'Milking Time',
  'Milk yield',
  'Conductivity',
  'temperature',
];

/// Local data source that writes output workbooks to disk.
class DairySenseWriter {
  const DairySenseWriter();

  void write(List<DairySenseRow> rows, String path) =>
      writeDairySenseXlsx(rows, path);
}

/// Write [rows] to an XLSX workbook at [path].
///
/// One sheet, first row the exact headers, one data row per record (FR-009).
/// Synchronous so the pipeline can run in a single `Isolate.run` call.
void writeDairySenseXlsx(List<DairySenseRow> rows, String path) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.tables.keys.first;
  if (defaultSheet != dairySenseSheetName) {
    excel.rename(defaultSheet, dairySenseSheetName);
  }
  final sheet = excel[dairySenseSheetName];
  sheet.appendRow(dairySenseHeaders.map(TextCellValue.new).toList());

  for (final row in rows) {
    sheet.appendRow([
      TextCellValue(row.date),
      TextCellValue(row.session),
      TextCellValue(row.unitNo),
      IntCellValue(row.cowNumber),
      IntCellValue(row.milkingTime),
      DoubleCellValue(row.milkYield),
      IntCellValue(row.conductivity),
      IntCellValue(row.temperature),
    ]);
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
