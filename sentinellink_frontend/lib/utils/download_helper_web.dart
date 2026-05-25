import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String?> downloadText(String fileName, String content) async {
  final web.Blob blob = web.Blob(
    <JSAny>[content.toJS].toJS,
    web.BlobPropertyBag(type: 'text/plain'),
  );
  _triggerDownload(fileName, blob);
  return null;
}

Future<String?> downloadBytes(String fileName, Uint8List bytes) async {
  final web.Blob blob = web.Blob(
    <JSAny>[bytes.buffer.toJS].toJS,
  );
  _triggerDownload(fileName, blob);
  return null;
}

void _triggerDownload(String fileName, web.Blob blob) {
  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement anchor =
      web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..setAttribute('download', fileName);
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
