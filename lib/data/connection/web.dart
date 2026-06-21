import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

DatabaseConnection openAppDatabaseConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'memora',
      sqlite3Uri: Uri.parse('/sqlite3.wasm'),
      driftWorkerUri: Uri.parse('/drift_worker.dart.js'),
    );
    return DatabaseConnection(result.resolvedExecutor);
  }));
}
