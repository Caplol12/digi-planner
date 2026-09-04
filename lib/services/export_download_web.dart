import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadFileWeb({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) {
  final uint8List = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final jsArray = uint8List.toJS;
  final blobParts = [jsArray].toJS;
  final blobOptions = web.BlobPropertyBag(type: mimeType);
  final blob = web.Blob(blobParts, blobOptions);
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  web.document.body?.removeChild(anchor);
  web.URL.revokeObjectURL(url);
}
