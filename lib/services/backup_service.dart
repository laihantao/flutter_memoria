import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../utils/file_ops.dart';

const _schemaVersion = 1;
const _dbFileName = 'memora.db';

class BackupManifest {
  final int schemaVersion;
  final String exportedAt;
  final Map<String, String> fileChecksums;

  BackupManifest({
    required this.schemaVersion,
    required this.exportedAt,
    required this.fileChecksums,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt,
        'fileChecksums': fileChecksums,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) =>
      BackupManifest(
        schemaVersion: json['schemaVersion'] as int,
        exportedAt: json['exportedAt'] as String,
        fileChecksums:
            Map<String, String>.from(json['fileChecksums'] as Map),
      );
}

class BackupService {
  /// Exports all data as a zip archive and returns the raw bytes.
  /// Throws [UnsupportedError] on web (no filesystem access).
  Future<Uint8List> exportBackup() async {
    if (kIsWeb) {
      throw UnsupportedError('Backup export is not available on web.');
    }

    final checksums = <String, String>{};
    final archive = Archive();

    // Add SQLite database
    final dbBytes = await readAppDocFileBytes(_dbFileName);
    if (dbBytes != null) {
      checksums[_dbFileName] = _sha256(dbBytes);
      archive.addFile(ArchiveFile(_dbFileName, dbBytes.length, dbBytes));
    }

    // Add all media files (memories, receipts, group photos)
    final mediaPaths = await listDocsDirRecursive('media');
    for (final relPath in mediaPaths) {
      final bytes = await readAppDocFileBytes(relPath);
      if (bytes != null) {
        checksums[relPath] = _sha256(bytes);
        archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
      }
    }

    // Add all avatar files
    final avatarPaths = await listDocsDirRecursive('avatars');
    for (final relPath in avatarPaths) {
      final bytes = await readAppDocFileBytes(relPath);
      if (bytes != null) {
        checksums[relPath] = _sha256(bytes);
        archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
      }
    }

    // Add manifest
    final manifest = BackupManifest(
      schemaVersion: _schemaVersion,
      exportedAt: DateTime.now().toIso8601String(),
      fileChecksums: checksums,
    );
    final manifestBytes = utf8
        .encode(const JsonEncoder.withIndent('  ').convert(manifest.toJson()));
    archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    final zipBytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBytes ?? []);
  }

  /// Restores from [zipBytes]. Returns null on success, error message on failure.
  /// Throws [UnsupportedError] on web.
  Future<String?> importBackup(Uint8List zipBytes) async {
    if (kIsWeb) {
      throw UnsupportedError('Backup restore is not available on web.');
    }

    final archive = ZipDecoder().decodeBytes(zipBytes);

    // Extract and validate manifest
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) return 'Invalid backup: missing manifest.json';

    late BackupManifest manifest;
    try {
      final json =
          jsonDecode(utf8.decode(manifestFile.content as List<int>));
      manifest = BackupManifest.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      return 'Invalid backup: malformed manifest';
    }

    if (manifest.schemaVersion > _schemaVersion) {
      return 'Backup was created with a newer version of Memora '
          '(schema v${manifest.schemaVersion}). '
          'Please update the app to restore this backup.';
    }

    // Verify checksums
    for (final entry in archive) {
      if (entry.name == 'manifest.json') continue;
      final expected = manifest.fileChecksums[entry.name];
      if (expected == null) continue;
      final actual = _sha256(entry.content as Uint8List);
      if (actual != expected) {
        return 'Backup integrity check failed for: ${entry.name}';
      }
    }

    // Destructive restore — clear existing media and avatars
    final mediaPaths = await listDocsDirRecursive('media');
    for (final rel in mediaPaths) {
      await deleteAppDocFile(rel);
    }
    final avatarPaths = await listDocsDirRecursive('avatars');
    for (final rel in avatarPaths) {
      await deleteAppDocFile(rel);
    }

    for (final entry in archive) {
      if (entry.isFile && entry.name != 'manifest.json') {
        await writeAppDocFileBytes(
            entry.name, entry.content as List<int>);
      }
    }

    return null;
  }

  String _sha256(List<int> bytes) => sha256.convert(bytes).toString();
}
