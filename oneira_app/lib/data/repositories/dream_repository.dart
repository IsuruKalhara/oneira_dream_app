import 'dart:convert';
import 'package:drift/drift.dart';
import '../db/database.dart';
import '../models.dart';

class DreamRepository {
  final AppDatabase db;
  DreamRepository(this.db);

  Stream<List<DreamEntry>> watchAll() => db.watchAll();
  Future<List<DreamEntry>> allOnce() => db.allOnce();
  Future<DreamEntry?> byId(String id) => db.byId(id);
  Future<void> delete(String id) => db.deleteById(id);
  Future<void> clearAll() => db.clearAll();

  Future<void> save({
    required String id,
    required DateTime createdAt,
    required String transcript,
    required Interpretation interp,
  }) {
    return db.upsert(DreamEntriesCompanion.insert(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      explanation: Value(interp.explanation),
      reflection: Value(interp.reflection),
      symbolsJson: Value(interp.symbolsJson()),
      quotesJson: Value(interp.quotesJson()),
      model: Value(interp.model),
    ));
  }
}

/// Parse the stored JSON columns back into UI models.
extension DreamEntryX on DreamEntry {
  List<DreamSymbol> get symbolList => (jsonDecode(symbolsJson) as List)
      .map((e) => DreamSymbol.fromJson(e as Map<String, dynamic>))
      .toList();
  List<Quote> get quoteList => (jsonDecode(quotesJson) as List)
      .map((e) => Quote.fromJson(e as Map<String, dynamic>))
      .toList();
}
