/// Header normalization (contracts/file-formats.md §1).
/// "Cow No." -> "cowno", "MPC Address" -> "mpcaddress", "Milk Dur." -> "milkdur"
String normalizeHeader(String cell) =>
    cell.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// FR-005: trim; int, else double with .0, else null.
int? normalizeCowNumber(String raw) {
  final t = raw.trim();
  final i = int.tryParse(t);
  if (i != null) return i;
  final d = double.tryParse(t);
  if (d != null && d == d.roundToDouble()) return d.toInt();
  return null; // "5.0" -> 5; "07" -> 7; "abc" -> null
}

/// FR-014: "HH:MM:SS" -> seconds; anything else -> null. Example 00:03:00 -> 180.
int? durationToSeconds(String? raw) {
  if (raw == null) return null;
  final parts = raw.split(':');
  if (parts.length != 3) return null;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  final s = int.tryParse(parts[2].trim());
  if (h == null || m == null || s == null) return null;
  if (h < 0 || m < 0 || m >= 60 || s < 0 || s >= 60) return null;
  return h * 3600 + m * 60 + s;
}

/// "HH:MM:SS" -> "HH:MM" (zero-padded, seconds dropped). Invalid/empty -> "00:00".
/// Example 00:03:00 -> "00:03"; 01:02:03 -> "01:02"; "-" -> "00:00".
String durationToHhMm(String? raw) {
  if (raw == null) return '00:00';
  final parts = raw.split(':');
  if (parts.length != 3) return '00:00';
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null || m < 0 || m >= 60) return '00:00';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}';
}

final _isoDatePattern = RegExp(r'^\s*(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\s*$');
final _shortDatePattern = RegExp(r'^\s*(\d{1,2})[-/.](\d{1,2})[-/.](\d{1,2})\s*$');

/// Parse a report date into a UTC [DateTime].
///
/// Accepts ISO (`2026-08-09`) and the real Alpro short format `yy.mm.dd`
/// (`26.08.08` = 2026-08-08). Returns `null` for anything unparsable.
DateTime? parseReportDate(String? date) {
  if (date == null || date.trim().isEmpty) return null;
  final iso = _isoDatePattern.firstMatch(date);
  if (iso != null) {
    return DateTime.utc(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  final short = _shortDatePattern.firstMatch(date);
  if (short != null) {
    // Real Alpro short dates are 2-digit `yy.mm.dd` (e.g. the Aug-2026
    // reports print `26.08.08` = 2026-08-08).
    final y = int.parse(short.group(1)!);
    final m = int.parse(short.group(2)!);
    final d = int.parse(short.group(3)!);
    final year = y < 100 ? y + 2000 : y;
    return DateTime.utc(year, m, d);
  }
  return null;
}

/// Convert a report date to `dd/mm/yyyy` (e.g. `14/03/2001`).
///
/// Accepts ISO (`2026-08-09` -> `09/08/2026`) and the real Alpro short format
/// `yy.mm.dd` (`26.08.08` -> `08/08/2026`). Anything unparsable is returned
/// unchanged so the user never loses the value.
String formatDateDdMmYyyy(String? date) {
  final dt = parseReportDate(date);
  if (dt == null) return date ?? '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
}
