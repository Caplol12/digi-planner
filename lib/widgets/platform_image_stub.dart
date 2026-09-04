import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

Widget buildPlatformFileImage({
  required String filePath,
  BoxFit fit = BoxFit.cover,
  Widget? errorWidget,
  double? width,
  double? height,
}) {
  if (filePath.startsWith('data:')) {
    try {
      final commaIndex = filePath.indexOf(',');
      final base64Str = commaIndex != -1 ? filePath.substring(commaIndex + 1) : filePath;
      final bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => errorWidget ?? const SizedBox.shrink(),
      );
    } catch (_) {
      return errorWidget ?? const SizedBox.shrink();
    }
  }
  return errorWidget ?? const SizedBox.shrink();
}

bool platformFileExists(String filePath) {
  if (filePath.startsWith('data:')) return true;
  return false;
}

Future<Uint8List?> readBytesFromPath(String path) async {
  if (path.startsWith('data:')) {
    try {
      final commaIndex = path.indexOf(',');
      final base64Str = commaIndex != -1 ? path.substring(commaIndex + 1) : path;
      return Uint8List.fromList(base64Decode(base64Str));
    } catch (_) {
      return null;
    }
  }
  try {
    if (path.length > 50 && !path.contains('/') && !path.contains('\\')) {
      return Uint8List.fromList(base64Decode(path));
    }
  } catch (_) {}
  return null;
}

Future<String?> saveLocalImageFile({Uint8List? bytes, String? sourcePath}) async {
  if (bytes != null) {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }
  return sourcePath;
}
