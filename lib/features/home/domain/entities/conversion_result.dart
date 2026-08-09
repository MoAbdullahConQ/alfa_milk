/// Returned by the pipeline after saving.
class ConversionResult {
  const ConversionResult({
    required this.reportCount,
    required this.selected,
    required this.found,
    required this.missing,
    this.warnings = const [],
    this.outputPath,
  });

  final int reportCount;
  final int selected;
  final int found;
  final List<int> missing;
  final List<String> warnings;
  final String? outputPath;
}
