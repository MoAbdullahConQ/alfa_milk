import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:dartz/dartz.dart' show Left;
import 'package:alfa_milk/core/errors/failures.dart';
import 'package:alfa_milk/core/utils/app_utils.dart';
import 'package:alfa_milk/features/home/data/data_sources/alpro_parser.dart';
import 'package:alfa_milk/features/home/data/data_sources/dairy_sense_writer.dart';
import 'package:alfa_milk/features/home/data/repos/conversion_repo_impl.dart';
import 'package:alfa_milk/features/home/domain/entities/alpro_record.dart';
import 'package:alfa_milk/features/home/domain/entities/alpro_report.dart';
import 'package:alfa_milk/features/home/domain/entities/cow_list.dart';
import 'package:alfa_milk/features/home/domain/entities/dairy_sense_row.dart';
import 'package:alfa_milk/features/home/domain/use_cases/build_dairy_sense_rows_use_case.dart';
import 'package:alfa_milk/features/home/domain/use_cases/convert_report_use_case.dart';
import 'package:alfa_milk/features/home/domain/use_cases/detect_missing_cows_use_case.dart';
import 'package:alfa_milk/features/home/domain/use_cases/filter_records_use_case.dart';
import 'package:alfa_milk/features/cow_list/data/cow_list_store.dart';

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

  group('durationToHhMm', () {
    test('formats HH:MM:SS to hh:mm dropping seconds', () {
      expect(durationToHhMm('00:03:00'), '00:03');
      expect(durationToHhMm('01:02:03'), '01:02');
      expect(durationToHhMm('12:45:59'), '12:45');
    });

    test('returns 00:00 for invalid or empty input', () {
      expect(durationToHhMm('-'), '00:00');
      expect(durationToHhMm(null), '00:00');
      expect(durationToHhMm(''), '00:00');
      expect(durationToHhMm('3:00'), '00:00');
    });
  });

  group('formatDateDdMmYyyy', () {
    test('converts ISO to dd/mm/yyyy', () {
      expect(formatDateDdMmYyyy('2026-08-09'), '09/08/2026');
      expect(formatDateDdMmYyyy('2001-03-14'), '14/03/2001');
    });

    test('converts real Alpro yy.mm.dd to dd/mm/yyyy', () {
      expect(formatDateDdMmYyyy('26.08.08'), '08/08/2026');
    });

    test('leaves unparsable input unchanged', () {
      expect(formatDateDdMmYyyy('n/a'), 'n/a');
      expect(formatDateDdMmYyyy(''), '');
      expect(formatDateDdMmYyyy(null), '');
    });
  });

  group('durationToHhMm', () {
    test('formats HH:MM:SS to hh:mm dropping seconds', () {
      expect(durationToHhMm('00:03:00'), '00:03');
      expect(durationToHhMm('01:02:03'), '01:02');
      expect(durationToHhMm('12:45:59'), '12:45');
    });

    test('returns 00:00 for invalid or empty input', () {
      expect(durationToHhMm('-'), '00:00');
      expect(durationToHhMm(null), '00:00');
      expect(durationToHhMm(''), '00:00');
      expect(durationToHhMm('3:00'), '00:00');
    });
  });

  group('formatDateDdMmYyyy', () {
    test('converts ISO to dd/mm/yyyy', () {
      expect(formatDateDdMmYyyy('2026-08-09'), '09/08/2026');
      expect(formatDateDdMmYyyy('2001-03-14'), '14/03/2001');
    });

    test('converts real Alpro yy.mm.dd to dd/mm/yyyy', () {
      expect(formatDateDdMmYyyy('26.08.08'), '08/08/2026');
    });

    test('leaves unparsable input unchanged', () {
      expect(formatDateDdMmYyyy('n/a'), 'n/a');
      expect(formatDateDdMmYyyy(''), '');
      expect(formatDateDdMmYyyy(null), '');
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
      expect(row.date, '26.08.08');
      expect(row.milkingTime, 0);
      expect(row.milkYield, 0.0);
    });
  });

  group('writeDairySenseXlsx (official Milking Import Format)', () {
    test('writes official headers, sheet name, and real Date/time cells', () {
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
              milkingTime: 225,
              milkYield: 12.5,
              conductivity: 0,
              temperature: 0,
            ),
            DairySenseRow(
              date: '26.08.08',
              session: '1',
              unitNo: '99',
              cowNumber: 12,
              milkingTime: 282,
              milkYield: 7.2,
              conductivity: 0,
              temperature: 0,
            ),
          ],
          path,
        );

        final bytes = File(path).readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        expect(excel.tables, hasLength(1));
        expect(excel.tables.keys.first, 'Sayfa1');
        final rows = excel.tables['Sayfa1']!.rows;

        final headers = rows.first.map((c) => c?.value?.toString()).toList();
        expect(headers, [
          'Date',
          'Session',
          'UnitNo',
          'CowNumber - in dairysense number-',
          'Milking Time -in seconds-',
          'Milk yield',
          'Conductivity',
          'temperature',
        ]);

        // Row 2: date ISO, session/unit text, 225 s -> 03:45.
        final r1 = rows[1];
        final date1 = r1[0]!.value as DateCellValue;
        expect(date1.asDateTimeUtc(), DateTime.utc(2026, 8, 9));
        expect(r1[0]!.cellStyle!.numberFormat.formatCode, 'dd/mm/yyyy');
        expect(r1[1]!.value, isA<TextCellValue>()); // 'AM' stays text
        final t1 = r1[4]!.value as TimeCellValue;
        expect(t1.hour, 3);
        expect(t1.minute, 45);
        // The excel package may normalize the custom 'hh:mm' time format to the
        // standard 'h:mm' on read-back; both render the same in Excel/DairySense.
        expect(r1[4]!.cellStyle!.numberFormat.formatCode, anyOf('hh:mm', 'h:mm'));
        final y1 = r1[5]!.value as DoubleCellValue;
        expect(y1.value, 12.5);

        // Row 3: date yy.mm.dd, numeric session/unit, 282 s -> 04:42.
        final r2 = rows[2];
        final date2 = r2[0]!.value as DateCellValue;
        expect(date2.asDateTimeUtc(), DateTime.utc(2026, 8, 8));
        final s2 = r2[1]!.value as IntCellValue; // session '1' numeric
        expect(s2.value, 1);
        final u2 = r2[2]!.value as IntCellValue; // unitNo '99' numeric
        expect(u2.value, 99);
        final t2 = r2[4]!.value as TimeCellValue;
        expect(t2.hour, 4);
        expect(t2.minute, 42);
        expect(r2[4]!.cellStyle!.numberFormat.formatCode, anyOf('hh:mm', 'h:mm'));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('maps milking-time seconds to DairySense minutes:seconds display', () {
      // 180 s -> 03:00, 225 s -> 03:45, 282 s -> 04:42.
      final dir = Directory.systemTemp.createTempSync('ds_time');
      final path = p.join(dir.path, 't.xlsx');
      try {
        writeDairySenseXlsx(
          const [
            DairySenseRow(
                date: '26.08.08',
                session: '1',
                unitNo: '1',
                cowNumber: 1,
                milkingTime: 180,
                milkYield: 1),
            DairySenseRow(
                date: '26.08.08',
                session: '1',
                unitNo: '2',
                cowNumber: 2,
                milkingTime: 225,
                milkYield: 1),
            DairySenseRow(
                date: '26.08.08',
                session: '1',
                unitNo: '3',
                cowNumber: 3,
                milkingTime: 282,
                milkYield: 1),
          ],
          path,
        );
        final rows = Excel.decodeBytes(File(path).readAsBytesSync())['Sayfa1'].rows;
        final expected = [(3, 0), (3, 45), (4, 42)];
        for (var i = 0; i < expected.length; i++) {
          final t = rows[i + 1][4]!.value as TimeCellValue;
          expect((t.hour, t.minute), expected[i]);
        }
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('performance + no-list guard (T026, FR-018/SC-006, C1)', () {
    test('parses/filters/builds a ~5000-record report responsively', () {
      // Synthetic report generated in-memory per contracts file-formats.md §1.
      final n = 5000;
      final sb = StringBuffer()
        ..writeln('<html><body>')
        ..writeln('<table><tr><td>Date</td><td>2026-08-09</td></tr>')
        ..writeln('<tr><td>Session</td><td>1</td></tr></table>')
        ..writeln('<table>')
        ..writeln('<tr><th>Cow No.</th><th>MPC Address</th>'
            '<th>Milk Yield</th><th>Milk Dur.</th></tr>');
      for (var i = 1; i <= n; i++) {
        sb.writeln(
            '<tr><td>$i</td><td>UNIT$i</td><td>12.5</td><td>00:03:00</td></tr>');
      }
      sb.writeln('</table></body></html>');

      final all = {for (var i = 1; i <= n; i++) i};
      final stopwatch = Stopwatch()..start();
      final report = parseAlproReport(sb.toString());
      final matched = FilterRecordsUseCase().call(report.records, all);
      final rows = BuildDairySenseRowsUseCase().call(report, matched);
      stopwatch.stop();

      expect(report.records, hasLength(n));
      expect(rows, hasLength(n));
      expect(rows.first.conductivity, 0);
      expect(rows.first.temperature, 0);
      // Generous bound for CI; SC-006 only requires no UI freeze.
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('ConvertReportUseCase with no cow list yields NoCowListFailure', () async {
      final uc = ConvertReportUseCase(ConversionRepoImpl());
      final result = await uc.call(
        alproHtmlPath: 'ignored.html',
        cowList: null,
        outputXlsxPath: 'out.xlsx',
      );
      final value = (result as Left).value;
      expect(value, isA<NoCowListFailure>());
      expect((value as NoCowListFailure).message, contains('Import a current cow list'));
    });

    test('runConversion with an empty cow set yields NoCowListFailure '
        '(never the FR-021 zero-match message)', () async {
      final repo = ConversionRepoImpl();
      final empty = CowList(
          cowNumbers: const <int>{},
          lastUpdated: DateTime.utc(2026, 8, 9));
      final result = await repo.runConversion(
        alproHtmlPath: 'ignored.html',
        cowList: empty,
        outputXlsxPath: 'out.xlsx',
      );
      expect((result as Left).value, isA<NoCowListFailure>());
    });
  });

  group('input non-mutation + large-list round-trip (T027, FR-019/FR-020)', () {
    late Directory tempDir;
    late String reportPath;
    late String outputPath;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('t027_');
      final html = '''
<html><body>
<table>
  <tr><td>Date</td><td>2026-08-09</td></tr>
  <tr><td>Session</td><td>1</td></tr>
</table>
<table>
  <tr><th>Cow No.</th><th>MPC Address</th><th>Milk Yield</th><th>Milk Dur.</th></tr>
  <tr><td>1</td><td>UNIT1</td><td>12.5</td><td>00:03:00</td></tr>
</table>
</body></html>''';
      reportPath = '${tempDir.path}${Platform.pathSeparator}alpro_report.html';
      File(reportPath).writeAsStringSync(html);
    });

    tearDownAll(() {
      tempDir.deleteSync(recursive: true);
    });

    test('FR-019: runConversion never modifies the source HTML file', () async {
      final sourceBytesBefore = File(reportPath).readAsBytesSync();
      final cowList = CowList(
        cowNumbers: const {1, 2, 3},
        lastUpdated: DateTime.utc(2026, 8, 9),
      );
      outputPath = '${tempDir.path}${Platform.pathSeparator}out.xlsx';

      final repo = ConversionRepoImpl();
      final result = await repo.runConversion(
        alproHtmlPath: reportPath,
        cowList: cowList,
        outputXlsxPath: outputPath,
      );

      expect(result.isRight(), isTrue);
      expect(await File(outputPath).exists(), isTrue,
          reason: 'output XLSX should be created');

      final sourceBytesAfter = File(reportPath).readAsBytesSync();
      expect(sourceBytesAfter, equals(sourceBytesBefore),
          reason: 'FR-019: source HTML must not be modified');
    });

    test('FR-020: CowListStore round-trips a 5,000-cow list without error',
        () async {
      final original = PathProviderPlatform.instance;
      try {
        PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

        final store = const CowListStore();
        final bigList = CowList(
          cowNumbers: Set<int>.from(List.generate(5000, (i) => i + 1)),
          lastUpdated: DateTime.utc(2026, 8, 9),
        );

        await store.saveCowList(bigList);
        final loaded = await store.getCowListFile();

        expect(loaded, isNotNull);
        expect(loaded!.cowNumbers, hasLength(5000));
        expect(loaded.cowNumbers.contains(1), isTrue);
        expect(loaded.cowNumbers.contains(5000), isTrue);
      } finally {
        PathProviderPlatform.instance = original;
      }
    });
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  final String _supportPath;

  _FakePathProviderPlatform(this._supportPath) : super();

  @override
  Future<String?> getTemporaryPath() async => null;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;

  @override
  Future<String?> getLibraryPath() async => null;

  @override
  Future<String?> getApplicationDocumentsPath() async => null;

  @override
  Future<String?> getApplicationCachePath() async => null;

  @override
  Future<String?> getExternalStoragePath() async => null;

  @override
  Future<List<String>?> getExternalCachePaths() async => null;

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async => null;

  @override
  Future<String?> getDownloadsPath() async => null;
}
