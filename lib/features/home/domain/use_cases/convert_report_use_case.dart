import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/conversion_result.dart';
import '../../domain/entities/cow_list.dart';
import '../../domain/repos/conversion_repo.dart';

/// Orchestrates the Alpro → DairySense conversion for the home feature.
class ConvertReportUseCase {
  final ConversionRepo conversionRepo;

  ConvertReportUseCase(this.conversionRepo);

  /// Throws a `NoCowListFailure` when no cow list is available.
  Future<Either<Failure, ConversionResult>> call({
    required String alproHtmlPath,
    required CowList? cowList,
    required String outputXlsxPath,
  }) async {
    if (cowList == null) {
      return const Left(NoCowListFailure(
          'Import a current cow list before converting.'));
    }
    return conversionRepo.runConversion(
      alproHtmlPath: alproHtmlPath,
      cowList: cowList,
      outputXlsxPath: outputXlsxPath,
    );
  }
}
