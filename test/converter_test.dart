import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:alfa_milk/core/utils/app_utils.dart';
import 'package:alfa_milk/features/home/data/data_sources/dairy_sense_writer.dart';
import 'package:alfa_milk/features/home/domain/entities/alpro_record.dart';
import 'package:alfa_milk/features/home/domain/entities/alpro_report.dart';
import 'package:alfa_milk/features/home/domain/entities/dairy_sense_row.dart';
import 'package:alfa_milk/features/home/domain/use_cases/build_dairy_sense_rows_use_case.dart';
import 'package:alfa_milk/features/home/domain/use_cases/detect_missing_cows_use_case.dart';
import 'package:alfa_milk/features/home/domain/use_cases/filter_records_use_case.dart';

Object? _rawValue(Data? data) {
  final cv = data?.value;
  if (cv is TextCellValue) return cv.value.toString();
  if (cv is IntCellValue) return cv.value;
  if (cv is DoubleCellValue) return cv.value;
  if (cv is BoolCellValue) return cv.value;
  return cv?.toString();
}

void main() {
  group('normalizeCowNumber (FR-005)', () {
    test('trims and parses integers and double-with-.0', () {
      expect(normalizeCowNumber('07'), 7);
      expect(normalizeCowNumber(' 5.0 '), 5);
      expect(normalizeCowNumber('5'), 5);
    });

    test('returns null for non-numeric input', () {
      expect(normalizeCowNumber('abc'), isNull);
      expect(normalizeCowNumber(''), isNull);
      expect(normalizeCowNumber('3.5'), isNull);
    });
  });

  group('durationToSeconds (FR-014)', () {
    test('parses HH:MM:SS', () {
      expect(durationToSeconds('00:03:00'), 180);
      expect(durationToSeconds('01:02:03'), 3723);
    });

    test('returns null for invalid input', () {
      expect(durationToSeconds('abc'), isNull);
      expect(durationToSeconds(null), isNull);
      expect(durationToSeconds('3:00'), isNull);
    });
  });

  group('filterRecords (FR-009)', () {
    final records = const [
      AlproRecord(cowNumber: 5),
      AlproRecord(cowNumber: 12),
      AlproRecord(cowNumber: 20),
      AlproRecord(cowNumber: 31),
    ];

    test('keeps only listed cows, preserving original order', () {
      final filtered =
          FilterRecordsUseCase().call(records, const {20, 5, 99});
      expect(filtered.map((r) => r.cowNumber), [5, 20]);
    });

    test('returns empty when nothing matches', () {
      expect(FilterRecordsUseCase().call(records, const {999}), isEmpty);
    });
  });

  group('detectMissingCows (FR-010)', () {
    test('returns selected cows absent from report, sorted ascending', () {
      final missing = DetectMissingCowsUseCase().call(
        selected: const {5, 31, 44, 12},
        inReport: const {12, 5},
      );
      expect(missing, [31, 44]);
    });

    test('returns empty when all selected are present', () {
      expect(
        DetectMissingCowsUseCase().call(
          selected: const {5, 12},
          inReport: const {5, 12},
        ),
        isEmpty,
      );
    });
  });

  group('buildDairySenseRows (FR-012/013/014)', () {
    test('builds rows with zero conductivity/temperature and seconds', () {
      final report = AlproReport(
        date: '2026-08-09',
        session: 'AM',
        records: const [
          AlproRecord(
            cowNumber: 5,
            unitNo: 'UNIT1',
            milkYield: 12.5,
            milkDur: '00:03:00',
          ),
        ],
      );

      final rows =
          BuildDairySenseRowsUseCase().call(report, report.records);

      expect(rows, hasLength(1));
      final row = rows.first;
      expect(row.date, '2026-08-09');
      expect(row.session, 'AM');
      expect(row.unitNo, 'UNIT1');
      expect(row.cowNumber, 5);
      expect(row.milkingTime, 180);
      expect(row.milkYield, 12.5);
      expect(row.conductivity, 0);
      expect(row.temperature, 0);
    });

    test('maps a "-" duration and 0 yield to 0 seconds / 0.0', () {
      final report = AlproReport(
        date: '26.08.08',
        session: '1',
        records: const [
          AlproRecord(cowNumber: 12, milkYield: 0.0, milkDur: '-'),
        ],
      );
      final rows =
          BuildDairySenseRowsUseCase().call(report, report.records);
      final row = rows.first;
      expect(row.milkingTime, 0);
      expect(row.milkYield, 0.0);
    });
  });

  group('writeDairySenseXlsx (contracts §3)', () {
    test('writes headers in exact order and readable row values', () {
      final dir = Directory.systemTemp.createTempSync('ds_writer');
      final path = p.join(dir.path, 'out.xlsx');

      try {
        writeDairySenseXlsx(
          const [
            DairySenseRow(
              date: '2026-08-09',
              session: 'AM',
              unitNo: 'UNIT1',
              cowNumber: 5,
              milkingTime: 180,
              milkYield: 12.5,
              conductivity: 0,
              temperature: 0,
            ),
          ],
          path,
        );

        final bytes = File(path).readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        expect(excel.tables, hasLength(1));
        final sheet = excel.tables.keys.first;
        final rows = excel.tables[sheet]!.rows;

        final headers = rows.first.map((c) => c?.value?.toString()).toList();
        expect(headers, [
          'Date',
          'Session',
          'UnitNo',
          'CowNumber',
          'Milking Time',
          'Milk yield',
          'Conductivity',
          'temperature',
        ]);

        final data = rows[1].map((c) => _rawValue(c)).toList();
        expect(data[0], '2026-08-09');
        expect(data[1], 'AM');
        expect(data[2], 'UNIT1');
        expect(data[3], 5);
        expect(data[4], 180);
        expect(data[5], 12.5);
        expect(data[6], 0);
        expect(data[7], 0);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
