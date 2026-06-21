import 'dart:typed_data';

Future<String> getDocsPath() async => '';

Future<String> copyToAppDocs(String sourcePath, String destRelPath) async => '';

Future<void> deleteAppDocFile(String relPath) async {}

Future<bool> appDocFileExists(String relPath) async => false;

Future<Uint8List?> readAppDocFileBytes(String relPath) async => null;

Future<Uint8List?> readAbsoluteFileBytes(String absPath) async => null;

Future<String> writeAppDocFileBytes(String relPath, List<int> bytes) async =>
    '';

Future<List<String>> listDocsDirRecursive(String relDir) async => [];

String joinPath(String a, String b) => '$a/$b';
