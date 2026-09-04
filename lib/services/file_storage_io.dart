import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'app_logger.dart';

Future<Directory?> _getStorageDirectory() async {
  debugPrint('--> [_getStorageDirectory] start');
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    debugPrint('--> [_getStorageDirectory] FLUTTER_TEST branch');
    final testDir = Directory('${Directory.systemTemp.path}/planwiz_test');
    if (!testDir.existsSync()) {
      testDir.createSync(recursive: true);
    }
    debugPrint('--> [_getStorageDirectory] returning ${testDir.path}');
    return testDir;
  }
  try {
    return await getApplicationDocumentsDirectory().timeout(const Duration(seconds: 2));
  } catch (e, st) {
    AppLog.e('FileStorageIO', 'Failed to get application documents directory', st);
    return null;
  }
}

Future<String?> readLocalFile(String fileName) async {
  try {
    final dir = await _getStorageDirectory();
    if (dir == null) return null;
    final file = File('${dir.path}/$fileName');
    if (file.existsSync()) {
      return file.readAsStringSync();
    }
    // Check backup if main file is missing
    final bakFile = File('${dir.path}/$fileName.bak');
    if (bakFile.existsSync()) {
      AppLog.w('FileStorageIO', 'Main file $fileName missing, recovering from .bak');
      return bakFile.readAsStringSync();
    }
  } catch (e, st) {
    AppLog.e('FileStorageIO', 'Failed to read local file $fileName', st);
  }
  return null;
}

Future<bool> writeLocalFile(String fileName, String content) async {
  try {
    final dir = await _getStorageDirectory();
    if (dir == null) return false;
    final file = File('${dir.path}/$fileName');
    final tmpFile = File('${dir.path}/$fileName.tmp');

    // Flush to disk
    tmpFile.writeAsStringSync(content, flush: true);

    // Keep a .bak of the previous good state if file exists and remove old destination for Windows compatibility
    if (file.existsSync()) {
      try {
        final bakFile = File('${dir.path}/$fileName.bak');
        bakFile.writeAsStringSync(file.readAsStringSync(), flush: true);
        file.deleteSync();
      } catch (_) {}
    }

    // Atomic rename with copy-fallback
    try {
      tmpFile.renameSync(file.path);
    } catch (_) {
      tmpFile.copySync(file.path);
      try {
        tmpFile.deleteSync();
      } catch (_) {}
    }
    return true;
  } catch (e, st) {
    AppLog.e('FileStorageIO', 'Failed to write local file $fileName', st);
    return false;
  }
}

Future<void> backupCorruptFile(String fileName, String corruptContent) async {
  try {
    final dir = await _getStorageDirectory();
    if (dir == null) return;
    final corruptFile = File('${dir.path}/$fileName.corrupt.bak');
    await corruptFile.writeAsString(corruptContent, flush: true);
    AppLog.w('FileStorageIO', 'Saved corrupt backup to: ${corruptFile.path}');
  } catch (e, st) {
    AppLog.e('FileStorageIO', 'Failed to backup corrupt file', st);
  }
}

bool get isTestEnvironment => false;
