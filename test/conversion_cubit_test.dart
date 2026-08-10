import 'package:flutter_test/flutter_test.dart';

import 'package:alfa_milk/features/home/data/repos/conversion_repo_impl.dart';
import 'package:alfa_milk/features/home/domain/use_cases/convert_report_use_case.dart';
import 'package:alfa_milk/features/home/presentation/manager/conversion_cubit/conversion_cubit.dart';

void main() {
  ConversionCubit build() =>
      ConversionCubit(convertReportUseCase: ConvertReportUseCase(ConversionRepoImpl()));

  group('ConversionCubit cancel/reset (T019 cancel bug)', () {
    test('starts idle', () {
      final cubit = build();
      expect(cubit.state, isA<ConversionInitial>());
      cubit.close();
    });

    test('showLoading enters Loading and reset returns to idle', () {
      final cubit = build();

      cubit.showLoading();
      expect(cubit.state, isA<ConversionLoading>());

      // Re-enables the CONVERT button without a conversion run.
      cubit.reset();
      expect(cubit.state, isA<ConversionInitial>());

      cubit.close();
    });
  });
}
