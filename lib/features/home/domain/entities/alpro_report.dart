import 'alpro_record.dart';

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
