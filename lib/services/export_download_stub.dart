void downloadFileWeb({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) {
  throw UnsupportedError('Web download is only supported on Web platform.');
}
