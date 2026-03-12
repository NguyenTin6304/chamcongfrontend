import 'dart:typed_data';

Future<String> saveBytesAsFile({
  required Uint8List bytes,
  required String fileName,
}) {
  throw UnsupportedError('File download is not supported on this platform.');
}
