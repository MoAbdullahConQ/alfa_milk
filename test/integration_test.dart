import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alfa_milk/features/home/data/repos/conversion_repo_impl.dart';
import 'package:alfa_milk/features/home/domain/entities/cow_list.dart';

/// T021 — end-to-end `runConversion` over the real customer files.
///
/// The real fixtures (`alpro_report.html`, `current_cow_list.xlsx`,
/// `dairy_sense_template.xlsx`) are not invented; they arrive from the
/// customer and are kept as regression fixtures (Constitution V/VI). While
/// they are absent this test skips gracefully (fixtures/README.md).
void main() {
  final reportPath = 'test/fixtures/alpro_report.html';
  final cowListPath = 'test/fixtures/current_cow_list.xlsx';

  final reportExists = File(reportPath).existsSync();
  final cowListExists = File(cowListPath).existsSync();

  test('T021 end-to-end runConversion over real files', () async {
    if (!reportExists || !cowListExists) {
      markTestSkipped(
          'Real fixture files absent; skipping until they arrive.');
      return;
    }

    // Cow numbers come from the real cow-list workbook (its first int column).
    final Excel excel;
    try {
      final bytes = File(cowListPath).readAsBytesSync();
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      markTestSkipped('Could not read cow-list fixture: $e');
      return;
    }
    final sheet = excel.tables.values
        .firstWhere((s) => s.rows.isNotEmpty, orElse: () => excel['Sheet1']);
    final cowNumbers = <int>{};
    for (final row in sheet.rows) {
      for (final data in row) {
        final value = data?.value;
        if (value != null) {
          final n = int.tryParse(value.toString());
          if (n != null) {
            cowNumbers.add(n);
            break;
          }
        }
      }
    }

    final tempDir = await Directory.systemTemp.createTemp('t021_');
    final outputPath =
        '${tempDir.path}${Platform.pathSeparator}dairy_sense_import.xlsx';
    try {
      final repo = ConversionRepoImpl();
      final result = await repo.runConversion(
        alproHtmlPath: reportPath,
        cowList: CowList(
          cowNumbers: cowNumbers,
          lastUpdated: DateTime.now(),
        ),
        outputXlsxPath: outputPath,
      );

      expect(result.isRight(), isTrue,
          reason: 'runConversion should succeed on real files');
      final value = result.getOrElse(() => throw StateError('no value'));

      expect(File(outputPath).existsSync(), isTrue,
          reason: 'output XLSX should be created');

      final out = Excel.decodeBytes(File(outputPath).readAsBytesSync());
      final outputSheet = out.tables.values.first;

      final headerRow =
          outputSheet.rows.first.map((d) => d?.value?.toString() ?? '').toList();
      expect(
        headerRow,
        ['Date', 'Session', 'UnitNo', 'CowNumber - in dairysense number-',
            'Milking Time -in seconds-', 'Milk yield', 'Conductivity',
            'temperature'],
        reason: 'verified DairySense header order (imported into real system)',
      );

      final dataRows = outputSheet.rows.skip(1).toList();
      expect(dataRows.length, value.found,
          reason: 'output row count = matching Alpro records');

      final exportedCows = <int>{};
      for (final row in dataRows) {
        final cowCell = row.length > 3 ? row[3]?.value?.toString() : null;
        if (cowCell != null) {
          final n = int.tryParse(cowCell);
          if (n != null) exportedCows.add(n);
        }
        // Milking Time is converted from seconds and present.
        // Conductivity/temperature are 0.
        final milkingTime = row.length > 4 ? row[4]?.value?.toString() : null;
        expect(milkingTime, isNotNull, reason: 'Milking Time cell present');
      }

      // Exported set = intersection of report × cow list.
      final reportCows = _extractReportCows(reportPath);
      final expectedIntersection =
          reportCows.intersection(cowNumbers);
      expect(exportedCows, expectedIntersection,
          reason: 'exported CowNumber set = report ∩ cow list');
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}

/// Best-effort cow numbers parsed from the report HTML (used only to compute
/// the expected intersection when the real file is present).
Set<int> _extractReportCows(String path) {
  final html = File(path).readAsStringSync();
  final matches =
      RegExp(r'\b(\d{1,6})\b').allMatches(html).map((m) => m.group(1)!).toList();
  return matches.map(int.parse).toSet();
}