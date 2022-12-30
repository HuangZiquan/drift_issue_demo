import 'package:drift/drift.dart';

class Sentences extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get description => text()();
}
