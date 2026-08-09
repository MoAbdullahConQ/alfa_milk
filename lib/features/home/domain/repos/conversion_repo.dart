import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/alpro_report.dart';
import '../../domain/entities/conversion_result.dart';
import '../../domain/entities/cow_list.dart';

/// Boundary between the use cases (domain) and the data layer.
abstract class ConversionRepo {
  /// Parse an Alpro HTML report at [htmlPath].
  Future<Either<Failure, AlproReport>> parseAlproReport(String htmlPath);

  /// Run the full pipeline and persist the workbook.
  Future<Either<Failure, ConversionResult>> runConversion({
    required String alproHtmlPath,
    required CowList cowList,
    required String outputXlsxPath,
  });
}
