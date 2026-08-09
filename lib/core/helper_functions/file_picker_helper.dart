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
