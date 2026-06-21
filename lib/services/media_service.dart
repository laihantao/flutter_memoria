import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../utils/file_ops.dart';

class MediaService {
  static Future<String?> resolveAbsolute(String? relativePath) async {
    if (relativePath == null) return null;
    final docs = await getDocsPath();
    if (docs.isEmpty) return null;
    return joinPath(docs, relativePath);
  }

  static Future<Uint8List?> readFileBytes(String? relativePath) async {
    if (relativePath == null) return null;
    return readAppDocFileBytes(relativePath);
  }

  static Future<void> deleteFile(String relativePath) async {
    await deleteAppDocFile(relativePath);
  }

  static Future<String> copyToAppDocs(
      String sourcePath, String relativeDestDir) async {
    final ext = p.extension(sourcePath);
    final fileName = p.basenameWithoutExtension(sourcePath);
    final destRelative = joinPath(relativeDestDir, '$fileName$ext');
    return copyToAppDocs(sourcePath, destRelative);
  }
}
