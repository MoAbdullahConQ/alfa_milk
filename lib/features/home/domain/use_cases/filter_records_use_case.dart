import '../../domain/entities/alpro_record.dart';

/// FR-009: keep records whose cowNumber is in list, original order.
class FilterRecordsUseCase {
  List<AlproRecord> call(List<AlproRecord> records, Set<int> cowNumbers) {
    return records.where((r) => cowNumbers.contains(r.cowNumber)).toList();
  }
}
