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
  return errorWidget ?? const SizedBox.shrink();
}

bool platformFileExists(String filePath) {
  return false;
}

Future<Uint8List?> readBytesFromPath(String path) async => null;

Future<String?> saveLocalImageFile({Uint8List? bytes, String? sourcePath}) async {
  if (bytes != null) {
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }
  return sourcePath;
}
