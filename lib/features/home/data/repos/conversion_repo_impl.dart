import 'dart:isolate';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/custom_exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/alpro_report.dart';
import '../../domain/entities/conversion_result.dart';
import '../../domain/entities/cow_list.dart';
import '../../domain/repos/conversion_repo.dart';
import '../../domain/use_cases/build_dairy_sense_rows_use_case.dart';
import '../../domain/use_cases/detect_missing_cows_use_case.dart';
import '../../domain/use_cases/filter_records_use_case.dart';
import '../data_sources/alpro_parser.dart';
import '../data_sources/dairy_sense_writer.dart';

/// Data-layer implementation backed by the local file system.
class ConversionRepoImpl implements ConversionRepo {
  final AlproParser _parser;
  final DairySenseWriter _writer;
  final FilterRecordsUseCase _filterRecords;
  final DetectMissingCowsUseCase _detectMissingCows;
  final BuildDairySenseRowsUseCase _buildRows;

  ConversionRepoImpl({
    AlproParser? parser,
    DairySenseWriter? writer,
    FilterRecordsUseCase? filterRecords,
    DetectMissingCowsUseCase? detectMissingCows,
    BuildDairySenseRowsUseCase? buildRows,
  })  : _parser = parser ?? const AlproParser(),
        _writer = writer ?? const DairySenseWriter(),
        _filterRecords = filterRecords ?? FilterRecordsUseCase(),
        _detectMissingCows = detectMissingCows ?? DetectMissingCowsUseCase(),
        _buildRows = buildRows ?? BuildDairySenseRowsUseCase();

  @override
  Future<Either<Failure, AlproReport>> parseAlproReport(String htmlPath) async {
    try {
      final report = await Isolate.run(() => _parser.parseFile(htmlPath));
      return Right(report);
    } on AlproParseError catch (e) {
      return Left(AlproParseFailure(e.toString()));
    } catch (e) {
      return Left(AlproParseFailure('could not read the file ($e)'));
    }
  }

  @override
  Future<Either<Failure, ConversionResult>> runConversion({
    required String alproHtmlPath,
    required CowList cowList,
    required String outputXlsxPath,
  }) async {
    if (cowList.cowNumbers.isEmpty) {
      return const Left(
          NoCowListFailure('Import a current cow list before converting.'));
    }

    try {
      final result = await Isolate.run(() => _pipeline(
            alproHtmlPath,
            cowList,
            outputXlsxPath,
          ));
      return Right(result);
    } on AlproParseError catch (e) {
      return Left(AlproParseFailure(e.toString()));
    } on OutputWriteError catch (e) {
      return Left(OutputWriteFailure(e.toString()));
    } catch (e) {
      return Left(AlproParseFailure('unexpected error: $e'));
    }
  }

  /// Pure synchronous pipeline so it can run inside a single `Isolate.run`.
  ConversionResult _pipeline(
      String htmlPath, CowList cowList, String outputXlsxPath) {
    final report = _parser.parseFile(htmlPath);
    final matched = _filterRecords.call(report.records, cowList.cowNumbers);
    final missing = _detectMissingCows.call(
      selected: cowList.cowNumbers,
      inReport: report.records.map((r) => r.cowNumber).toSet(),
    );
    final rows = _buildRows.call(report, matched);
    if (rows.isEmpty) {
      throw const AlproParseError(
          'no records matched the current cow list; nothing to export');
    }

    final result = ConversionResult(
      reportCount: report.records.length,
      selected: cowList.cowNumbers.length,
      found: matched.length,
      missing: missing,
      warnings: report.warnings,
      outputPath: outputXlsxPath,
    );

    _writer.write(rows, outputXlsxPath);
    return result;
  }
}
