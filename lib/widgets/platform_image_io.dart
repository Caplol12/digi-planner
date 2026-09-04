import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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

  final file = File(filePath);
  if (!file.existsSync()) {
    return errorWidget ?? const SizedBox.shrink();
  }
  return Image.file(
    file,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (context, error, stackTrace) => errorWidget ?? const SizedBox.shrink(),
  );
}

bool platformFileExists(String filePath) {
  if (filePath.startsWith('data:')) return true;
  try {
    return File(filePath).existsSync();
  } catch (_) {
    return false;
  }
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
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (_) {}
  return null;
}

Future<String?> saveLocalImageFile({Uint8List? bytes, String? sourcePath}) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/journal_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final targetFile = File('${imagesDir.path}/img_${const Uuid().v4()}.png');
    if (bytes != null) {
      await targetFile.writeAsBytes(bytes);
      return targetFile.path;
    } else if (sourcePath != null) {
      await File(sourcePath).copy(targetFile.path);
      return targetFile.path;
    }
  } catch (_) {}
  return sourcePath;
}
