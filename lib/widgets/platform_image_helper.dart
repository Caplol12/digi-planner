import 'dart:typed_data';
import 'package:image/image.dart' as img;

export 'platform_image_stub.dart'
    if (dart.library.io) 'platform_image_io.dart';

/// Safely downsamples and compresses image bytes to prevent out-of-memory
/// and browser localStorage QuotaExceededError.
Uint8List compressImageBytes(
  Uint8List original, {
  int maxDimension = 1024,
  int quality = 75,
}) {
  if (original.length < 250 * 1024) {
    return original;
  }
  try {
    final decoded = img.decodeImage(original);
    if (decoded == null) return original;

    img.Image resized = decoded;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      if (decoded.width >= decoded.height) {
        resized = img.copyResize(decoded, width: maxDimension);
      } else {
        resized = img.copyResize(decoded, height: maxDimension);
      }
    }
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  } catch (_) {
    return original;
  }
}

