import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/alpro_record.dart';
import '../../domain/entities/alpro_report.dart';
import '../../domain/entities/dairy_sense_row.dart';

/// FR-012/013/014: build the output rows (Conductivity/temperature = 0).
class BuildDairySenseRowsUseCase {
  List<DairySenseRow> call(AlproReport report, List<AlproRecord> matched) {
    return matched.map((r) {
      final seconds = durationToSeconds(r.milkDur);
      return DairySenseRow(
        date: report.date,
        session: report.session,
        unitNo: r.unitNo,
        cowNumber: r.cowNumber,
        milkingTime: seconds ?? 0,
        milkYield: r.milkYield ?? 0,
        conductivity: 0,
        temperature: 0,
      );
    }).toList();
  }
}
