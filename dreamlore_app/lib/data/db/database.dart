import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// One saved dream + its interpretation. Local-first: this never leaves the
/// device. Structured fields (symbols/quotes) are stored as JSON strings.
class DreamEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get transcript => text()();
  TextColumn get explanation => text().withDefault(const Constant(''))();
  TextColumn get reflection => text().withDefault(const Constant(''))();
  TextColumn get symbolsJson => text().withDefault(const Constant('[]'))();
  TextColumn get quotesJson => text().withDefault(const Constant('[]'))();
  TextColumn get model => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [DreamEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() => driftDatabase(name: 'dreamlore');

  Stream<List<DreamEntry>> watchAll() =>
      (select(dreamEntries)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<List<DreamEntry>> allOnce() => select(dreamEntries).get();

  Future<DreamEntry?> byId(String id) =>
      (select(dreamEntries)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(DreamEntriesCompanion entry) =>
      into(dreamEntries).insertOnConflictUpdate(entry);

  Future<void> deleteById(String id) =>
      (delete(dreamEntries)..where((t) => t.id.equals(id))).go();

  Future<void> clearAll() => delete(dreamEntries).go();
}
