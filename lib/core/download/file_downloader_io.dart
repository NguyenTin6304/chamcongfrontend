import 'dart:io';
import 'dart:typed_data';

Future<String> saveBytesAsFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  final sanitized = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$sanitized');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
