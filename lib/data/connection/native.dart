import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

DatabaseConnection openAppDatabaseConnection() {
  return DatabaseConnection(LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'memora.db'));
    return NativeDatabase.createInBackground(file);
  }));
}
