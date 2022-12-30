import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';

import 'tables.dart';

part 'database.g.dart';

void setupSqlCipher() {
  open.overrideFor(OperatingSystem.android, () => DynamicLibrary.open('libsqlcipher.so'));
}

late DriftIsolate driftIsolate;

DatabaseConnection createDriftIsolateAndConnect() {
  return DatabaseConnection.delayed(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final path = p.join(dbFolder.path, "demo.sqlite");
    driftIsolate = await createDriftIsolate(path);
    DatabaseConnection backgroundConnection = await driftIsolate.connect();
    QueryExecutor executor = await constructAppDbExecutor(path);
    return backgroundConnection.withExecutor(
      MultiExecutor(
        write: backgroundConnection.executor,
        read: executor,
      ),
    );
  }());
}

Future<DriftIsolate> createDriftIsolate(String path) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_startBackground, _IsolateStartRequest(receivePort.sendPort, path));
  return await receivePort.first as DriftIsolate;
}

void _startBackground(_IsolateStartRequest request) async {
  QueryExecutor? executor = await constructAppDbExecutor(request.targetPath);
  DriftIsolate driftIsolate = DriftIsolate.inCurrent(
    () => DatabaseConnection(executor),
  );
  request.sendDriftIsolate.send(driftIsolate);
}

Future<QueryExecutor> constructAppDbExecutor(String path) async {
  setupSqlCipher();
  final executor = LazyDatabase(() async {
    return NativeDatabase(
      File(path),
      setup: (rawDb) {
        rawDb.execute('pragma journal_mode = WAL;');
      },
    );
  });
  return executor;
}

class _IsolateStartRequest {
  final SendPort sendDriftIsolate;
  final String targetPath;

  _IsolateStartRequest(this.sendDriftIsolate, this.targetPath);
}

AppDatabase openDB() {
  return AppDatabase.connect(createDriftIsolateAndConnect());
}

@DriftDatabase(tables: [Sentences])
class AppDatabase extends _$AppDatabase {
  AppDatabase.connect(DatabaseConnection connection) : super.connect(connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) {
          return m.createAll();
        },
      );
}
