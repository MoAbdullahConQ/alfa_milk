/// FR-010: selected cows absent from the report, sorted ascending.
class DetectMissingCowsUseCase {
  List<int> call({required Set<int> selected, required Set<int> inReport}) {
    final missing = selected.where((c) => !inReport.contains(c)).toList()
      ..sort();
    return missing;
  }
}
