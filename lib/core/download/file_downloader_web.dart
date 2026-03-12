import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

Future<String> saveBytesAsFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  final blob = html.Blob(<dynamic>[bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return 'Downloaded in browser: $fileName';
}
