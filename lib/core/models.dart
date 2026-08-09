/// One milking event row parsed from the Alpro HTML table.
class AlproRecord {
  const AlproRecord({
    required this.cowNumber,
    this.unitNo = '',
    this.milkYield,
    this.milkDur,
  });

  final int cowNumber;
  final String unitNo;
  final double? milkYield;
  final String? milkDur;
}

/// Result of parsing the HTML document.
class AlproReport {
  const AlproReport({
    required this.date,
    required this.session,
    required this.records,
    this.warnings = const [],
  });

  final String date;
  final String session;
  final List<AlproRecord> records;
  final List<String> warnings;
}

/// The persisted current list.
class CowList {
  const CowList({required this.cowNumbers, required this.lastUpdated});

  final Set<int> cowNumbers;
  final DateTime lastUpdated;
}

/// One output row for the workbook.
class DairySenseRow {
  const DairySenseRow({
    required this.date,
    required this.session,
    required this.unitNo,
    required this.cowNumber,
    required this.milkingTime,
    required this.milkYield,
    this.conductivity = 0,
    this.temperature = 0,
  });

  final String date;
  final String session;
  final String unitNo;
  final int cowNumber;
  final int milkingTime;
  final double milkYield;
  final int conductivity;
  final int temperature;
}

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
