import 'package:file_picker/file_picker.dart';

/// Opens the native file picker filtered to HTML files.
///
/// Returns the absolute path of the picked file, or `null` if the user
/// cancelled. Reusable by any screen needing an Alpro report file.
Future<String?> pickHtmlFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['html'],
  );
  if (result != null && result.files.isNotEmpty) {
    return result.files.first.path;
  }
  return null;
}

/// Opens the native save dialog for the DairySense output workbook.
///
/// The user picks the destination folder (and may edit the file name) every
/// time a conversion is about to be written (FR-015). Returns the absolute
/// output path, or `null` if the user cancelled.
Future<String?> pickOutputXlsxPath() {
  return FilePicker.saveFile(
    dialogTitle: 'Choose where to save the DairySense file',
    fileName: _defaultOutputFileName(),
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
}

/// `DairySense_Import_<YYYY-MM-DD_HHmmss>.xlsx`, e.g.
/// `DairySense_Import_2026-08-10_153045.xlsx`.
String _defaultOutputFileName() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${now.year.toString().padLeft(4, '0')}-${two(now.month)}-'
      '${two(now.day)}';
  final time = '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  return 'DairySense_Import_${date}_$time.xlsx';
}
