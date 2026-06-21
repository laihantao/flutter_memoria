import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> getDocsPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}

/// Copies [sourcePath] (absolute, e.g. from image_picker) into the app
/// documents directory at [destRelPath] (relative).  Returns [destRelPath].
Future<String> copyToAppDocs(String sourcePath, String destRelPath) async {
  final docs = await getDocsPath();
  final destAbs = p.join(docs, destRelPath);
  await Directory(p.dirname(destAbs)).create(recursive: true);
  await File(sourcePath).copy(destAbs);
  return destRelPath;
}

Future<void> deleteAppDocFile(String relPath) async {
  final docs = await getDocsPath();
  final file = File(p.join(docs, relPath));
  if (await file.exists()) await file.delete();
}

Future<bool> appDocFileExists(String relPath) async {
  final docs = await getDocsPath();
  return File(p.join(docs, relPath)).exists();
}

Future<Uint8List?> readAppDocFileBytes(String relPath) async {
  final docs = await getDocsPath();
  final file = File(p.join(docs, relPath));
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<Uint8List?> readAbsoluteFileBytes(String absPath) async {
  final file = File(absPath);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

/// Writes [bytes] to [relPath] relative to app docs. Returns absolute path.
Future<String> writeAppDocFileBytes(String relPath, List<int> bytes) async {
  final docs = await getDocsPath();
  final absPath = p.join(docs, relPath);
  await Directory(p.dirname(absPath)).create(recursive: true);
  await File(absPath).writeAsBytes(bytes);
  return absPath;
}

/// Returns relative paths of all files under [relDir] in app docs.
Future<List<String>> listDocsDirRecursive(String relDir) async {
  final docs = await getDocsPath();
  final dir = Directory(p.join(docs, relDir));
  if (!await dir.exists()) return [];
  final relPaths = <String>[];
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      relPaths.add(p.relative(entity.path, from: docs));
    }
  }
  return relPaths;
}

String joinPath(String a, String b) => p.join(a, b);
