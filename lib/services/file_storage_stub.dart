Future<String?> readLocalFile(String fileName) async => null;
Future<bool> writeLocalFile(String fileName, String content) async => false;
Future<void> backupCorruptFile(String fileName, String corruptContent) async {}
bool get isTestEnvironment => false;
