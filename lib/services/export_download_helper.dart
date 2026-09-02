import 'export_download_stub.dart'
    if (dart.library.html) 'export_download_web.dart';

void triggerWebDownload({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) {
  downloadFileWeb(bytes: bytes, fileName: fileName, mimeType: mimeType);
}
