import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Android: Storage Access Framework "Save as" dialog (file_picker writes the
/// bytes itself, no storage permission needed).
/// Desktop: native save dialog returns a path, and we write the file.
Future<String?> saveBytes(String fileName, Uint8List bytes) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Export LexiFlip deck',
    fileName: fileName,
    type: FileType.any,
    bytes: bytes,
  );
  if (path == null) return null;

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final target = path.toLowerCase().endsWith('.json') ? path : '$path.json';
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }
  return path;
}
