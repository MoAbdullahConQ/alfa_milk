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
