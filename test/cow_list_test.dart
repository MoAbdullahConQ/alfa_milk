import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:alfa_milk/core/errors/custom_exceptions.dart';
import 'package:alfa_milk/features/cow_list/data/cow_list_loader.dart';
import 'package:alfa_milk/features/cow_list/data/cow_list_store.dart';
import 'package:alfa_milk/features/home/domain/entities/cow_list.dart';

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
  Future<List<String>?> getExternalStoragePaths(
      {StorageDirectory? type}) async => null;

  @override
  Future<String?> getDownloadsPath() async => null;
}

void main() {
  late Directory tempDir;
  final store = const CowListStore();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('t013_');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  void useFakePlatform() {
    PathProviderPlatform.instance =
        _FakePathProviderPlatform(tempDir.path);
  }

  group('CowListStore save/load round-trip (FR-003)', () {
    test('saves and loads a cow list preserving numbers and timestamp', () async {
      final original = PathProviderPlatform.instance;
      try {
        useFakePlatform();
        final expected = CowList(
          cowNumbers: const {1, 7, 42, 103},
          lastUpdated: DateTime.utc(2026, 8, 9, 14, 30),
        );

        await store.saveCowList(expected);
        final loaded = await store.getCowListFile();

        expect(loaded, isNotNull);
        expect(loaded!.cowNumbers, equals(expected.cowNumbers));
        expect(loaded.lastUpdated, equals(expected.lastUpdated));
      } finally {
        PathProviderPlatform.instance = original;
      }
    });

    test('round-trips a large 5,000-cow list (no cap, FR-020)', () async {
      final original = PathProviderPlatform.instance;
      try {
        useFakePlatform();
        final bigList = CowList(
          cowNumbers: Set<int>.from(List.generate(5000, (i) => i + 1)),
          lastUpdated: DateTime.utc(2026),
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

    test('returns null when no cow_list.json exists yet', () async {
      final original = PathProviderPlatform.instance;
      try {
        useFakePlatform();
        final file = File(
            '${tempDir.path}${Platform.pathSeparator}cow_list.json');
        if (file.existsSync()) file.deleteSync();
        final loaded = await store.getCowListFile();
        expect(loaded, isNull);
      } finally {
        PathProviderPlatform.instance = original;
      }
    });
  });

  group('CowListStore corrupt/malformed file (T016, never crash)', () {
    test('returns null for non-JSON content', () async {
      final original = PathProviderPlatform.instance;
      try {
        useFakePlatform();
        final file = File(
            '${tempDir.path}${Platform.pathSeparator}cow_list.json');
        file.writeAsStringSync('this is not json{{{');

        expect(await store.getCowListFile(), isNull);
      } finally {
        PathProviderPlatform.instance = original;
      }
    });

    test('returns null for JSON missing required keys', () async {
      final original = PathProviderPlatform.instance;
      try {
        useFakePlatform();
        final file = File(
            '${tempDir.path}${Platform.pathSeparator}cow_list.json');
        file.writeAsStringSync('{"foo":"bar"}');

        expect(await store.getCowListFile(), isNull);
      } finally {
        PathProviderPlatform.instance = original;
      }
    });

    test('returns null when cowNumbers is empty or invalid', () async {
      final original = PathProviderPlatform.instance;
      try {
        useFakePlatform();
        final file = File(
            '${tempDir.path}${Platform.pathSeparator}cow_list.json');
        file.writeAsStringSync(
            '{"cowNumbers":[],"lastUpdated":"2026-08-09"}');

        expect(await store.getCowListFile(), isNull);
      } finally {
        PathProviderPlatform.instance = original;
      }
    });
  });

  group('CowListStore validation on load (T016)', () {
    test('drops non-integer and negative numbers from the persisted list',
        () async {
      final original = PathProviderPlatform.instance;
      try {
        useFakePlatform();
        final file = File(
            '${tempDir.path}${Platform.pathSeparator}cow_list.json');
        file.writeAsStringSync(
            '{"cowNumbers":["1", 2, 3.7, -5, 101],"lastUpdated":"2026-08-09"}');

        final loaded = await store.getCowListFile();

        expect(loaded, isNotNull);
        // Non-numbers dropped; doubles truncated (3.7 -> 3); negatives dropped.
        expect(loaded!.cowNumbers, {2, 3, 101});
      } finally {
        PathProviderPlatform.instance = original;
      }
    });
  });

  group('loadCowListFromXlsx header detection (T013, FR-004)', () {
    late File xlsx;

    File writeXlsx(List<List<Object>> rows) {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      for (final row in rows) {
        sheet.appendRow(row.map((v) {
          if (v is int) return IntCellValue(v);
          if (v is double) return DoubleCellValue(v);
          return TextCellValue(v.toString());
        }).toList());
      }
      final bytes = excel.encode();
      final f = File('${tempDir.path}${Platform.pathSeparator}'
          'cowlist_${DateTime.now().microsecondsSinceEpoch}.xlsx');
      f.writeAsBytesSync(bytes!);
      return f;
    }

    test('detects the "Cow Number" header and reads its column', () {
      xlsx = writeXlsx([
        ['Cow Number', 'Milk Yield', 'Milk Dur.'],
        ['007', '12.5', '00:03:00'],
        ['3', '9.0', '00:02:00'],
        ['42', '10.0', '00:04:00'],
      ]);
      final result = loadCowListFromXlsx(xlsx.path);
      expect(result.cowNumbers, [7, 3, 42]);
      expect(result.usedFallback, isFalse);
      expect(result.warnings, isEmpty);
    });

    test('recognizes a header that normalizes to cownum* or equals cow', () {
      // "Cow No." -> "cowno" is deliberately NOT a match (contract §2).
      for (final header in ['Cow Number', 'cow']) {
        xlsx = writeXlsx([
          [header, 'Milk Yield'],
          ['1', '8.0'],
          ['2', '9.0'],
        ]);
        final result = loadCowListFromXlsx(xlsx.path);
        expect(result.cowNumbers, [1, 2],
            reason: 'header "$header" should be recognized');
        expect(result.usedFallback, isFalse,
            reason: 'header "$header" should be recognized');
      }
    });

    test('falls back to first int column and sets usedFallback when no header',
        () {
      xlsx = writeXlsx([
        ['Tag', 'Note'],
        ['11', 'alpha'],
        ['22', 'beta'],
      ]);
      final result = loadCowListFromXlsx(xlsx.path);
      expect(result.cowNumbers, [11, 22]);
      expect(result.usedFallback, isTrue);
    });

    test('deduplicates repeated cow numbers, preserving first-seen order', () {
      xlsx = writeXlsx([
        ['Cow No.', 'x'],
        ['5', 'a'],
        ['05', 'b'],
        ['5', 'c'],
        ['9', 'd'],
      ]);
      final result = loadCowListFromXlsx(xlsx.path);
      expect(result.cowNumbers, [5, 9]);
      expect(result.warnings, isEmpty);
    });

    test('collects non-integer cells as warnings and keeps valid ones', () {
      xlsx = writeXlsx([
        ['Cow No.', 'x'],
        ['1', 'a'],
        ['abc', 'b'],
        ['2', 'c'],
        ['', 'd'],
      ]);
      final result = loadCowListFromXlsx(xlsx.path);
      expect(result.cowNumbers, [1, 2]);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first, contains('abc'));
    });

    test('throws CowListError when no column yields a cow number', () {
      xlsx = writeXlsx([
        ['Name', 'Note'],
        ['holstein', 'alpha'],
        ['jersey', 'beta'],
      ]);
      expect(() => loadCowListFromXlsx(xlsx.path),
          throwsA(isA<CowListError>()));
    });

    test('throws CowListError for a workbook with no non-empty rows', () {
      xlsx = writeXlsx([]);
      // Empty sheet may still be considered "no data".
      expect(() => loadCowListFromXlsx(xlsx.path),
          throwsA(isA<CowListError>()));
    });
  });
}