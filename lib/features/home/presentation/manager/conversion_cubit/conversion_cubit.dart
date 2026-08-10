import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/conversion_result.dart';
import '../../../domain/entities/cow_list.dart';
import '../../../domain/use_cases/convert_report_use_case.dart';

part 'conversion_state.dart';

/// Manages the Alpro → DairySense conversion flow state for the home feature.
class ConversionCubit extends Cubit<ConversionState> {
  final ConvertReportUseCase convertReportUseCase;

  ConversionCubit({required this.convertReportUseCase})
      : super(ConversionInitial());

  /// Show a loading state for UI work that precedes the write (e.g. preview).
  void showLoading() => emit(ConversionLoading());

  /// Runs the pipeline. Callers pass the output path (save flow lands in US4).
  Future<void> convert({
    required String alproHtmlPath,
    required CowList? cowList,
    required String outputXlsxPath,
  }) async {
    emit(ConversionLoading());
    final result = await convertReportUseCase.call(
      alproHtmlPath: alproHtmlPath,
      cowList: cowList,
      outputXlsxPath: outputXlsxPath,
    );
    result.fold(
      (failure) => emit(ConversionFailure(failure.message)),
      (conversionResult) => emit(ConversionSuccess(conversionResult)),
    );
  }
}
