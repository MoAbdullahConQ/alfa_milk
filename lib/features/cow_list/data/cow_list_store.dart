import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../home/domain/entities/cow_list.dart';

/// Persists the active cow list to a single JSON file in the app support dir
/// (contracts/file-formats.md §4). Missing/corrupt file → no list, never crash.
class CowListStore {
  const CowListStore();

  /// Saves [cowList] to `cow_list.json`. The caller must have validated the
  /// new list already (FR-008: only overwrite after full validation).
  Future<void> saveCowList(CowList cowList) async {
    final file = await _cowListFile();
    final json = jsonEncode({
      'cowNumbers': cowList.cowNumbers.toList(),
      'lastUpdated': cowList.lastUpdated.toIso8601String(),
    });
    await file.writeAsString(json);
  }

  /// Loads the persisted list, or `null` when missing or corrupt.
  Future<CowList?> getCowListFile() async {
    try {
      final file = await _cowListFile();
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      final numbers = decoded['cowNumbers'];
      final updated = decoded['lastUpdated'];
      if (numbers is! List || updated is! String) return null;
      final cowNumbers = numbers
          .whereType<num>()
          .map((n) => n.toInt())
          .where((n) => n >= 0)
          .toSet();
      if (cowNumbers.isEmpty) return null;
      return CowList(
        cowNumbers: cowNumbers,
        lastUpdated: DateTime.tryParse(updated) ?? DateTime.now(),
      );
    } catch (e) {
      return null; // corrupt JSON → no list, never crash
    }
  }

  Future<File> _cowListFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}cow_list.json');
  }
}

/// Convenience for picking an XLSX cow-list file (FR-004/US2).
Future<String?> pickCowListXlsx() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
  if (result != null && result.files.isNotEmpty) {
    return result.files.first.path;
  }
  return null;
}
