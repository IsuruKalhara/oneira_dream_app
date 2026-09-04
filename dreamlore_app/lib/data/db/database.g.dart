// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DreamEntriesTable extends DreamEntries
    with TableInfo<$DreamEntriesTable, DreamEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DreamEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _reflectionMeta = const VerificationMeta(
    'reflection',
  );
  @override
  late final GeneratedColumn<String> reflection = GeneratedColumn<String>(
    'reflection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _symbolsJsonMeta = const VerificationMeta(
    'symbolsJson',
  );
  @override
  late final GeneratedColumn<String> symbolsJson = GeneratedColumn<String>(
    'symbols_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _quotesJsonMeta = const VerificationMeta(
    'quotesJson',
  );
  @override
  late final GeneratedColumn<String> quotesJson = GeneratedColumn<String>(
    'quotes_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    transcript,
    explanation,
    reflection,
    symbolsJson,
    quotesJson,
    model,
    imagePath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dream_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DreamEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    } else if (isInserting) {
      context.missing(_transcriptMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    }
    if (data.containsKey('reflection')) {
      context.handle(
        _reflectionMeta,
        reflection.isAcceptableOrUnknown(data['reflection']!, _reflectionMeta),
      );
    }
    if (data.containsKey('symbols_json')) {
      context.handle(
        _symbolsJsonMeta,
        symbolsJson.isAcceptableOrUnknown(
          data['symbols_json']!,
          _symbolsJsonMeta,
        ),
      );
    }
    if (data.containsKey('quotes_json')) {
      context.handle(
        _quotesJsonMeta,
        quotesJson.isAcceptableOrUnknown(data['quotes_json']!, _quotesJsonMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DreamEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DreamEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      )!,
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      )!,
      reflection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reflection'],
      )!,
      symbolsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbols_json'],
      )!,
      quotesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quotes_json'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
    );
  }

  @override
  $DreamEntriesTable createAlias(String alias) {
    return $DreamEntriesTable(attachedDatabase, alias);
  }
}

class DreamEntry extends DataClass implements Insertable<DreamEntry> {
  final String id;
  final DateTime createdAt;
  final String transcript;
  final String explanation;
  final String reflection;
  final String symbolsJson;
  final String quotesJson;
  final String model;

  /// Path of the generated dream picture inside the app's documents dir, or
  /// empty. Only the path is stored; the bytes live as a file.
  final String imagePath;
  const DreamEntry({
    required this.id,
    required this.createdAt,
    required this.transcript,
    required this.explanation,
    required this.reflection,
    required this.symbolsJson,
    required this.quotesJson,
    required this.model,
    required this.imagePath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['transcript'] = Variable<String>(transcript);
    map['explanation'] = Variable<String>(explanation);
    map['reflection'] = Variable<String>(reflection);
    map['symbols_json'] = Variable<String>(symbolsJson);
    map['quotes_json'] = Variable<String>(quotesJson);
    map['model'] = Variable<String>(model);
    map['image_path'] = Variable<String>(imagePath);
    return map;
  }

  DreamEntriesCompanion toCompanion(bool nullToAbsent) {
    return DreamEntriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      transcript: Value(transcript),
      explanation: Value(explanation),
      reflection: Value(reflection),
      symbolsJson: Value(symbolsJson),
      quotesJson: Value(quotesJson),
      model: Value(model),
      imagePath: Value(imagePath),
    );
  }

  factory DreamEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DreamEntry(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      transcript: serializer.fromJson<String>(json['transcript']),
      explanation: serializer.fromJson<String>(json['explanation']),
      reflection: serializer.fromJson<String>(json['reflection']),
      symbolsJson: serializer.fromJson<String>(json['symbolsJson']),
      quotesJson: serializer.fromJson<String>(json['quotesJson']),
      model: serializer.fromJson<String>(json['model']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'transcript': serializer.toJson<String>(transcript),
      'explanation': serializer.toJson<String>(explanation),
      'reflection': serializer.toJson<String>(reflection),
      'symbolsJson': serializer.toJson<String>(symbolsJson),
      'quotesJson': serializer.toJson<String>(quotesJson),
      'model': serializer.toJson<String>(model),
      'imagePath': serializer.toJson<String>(imagePath),
    };
  }

  DreamEntry copyWith({
    String? id,
    DateTime? createdAt,
    String? transcript,
    String? explanation,
    String? reflection,
    String? symbolsJson,
    String? quotesJson,
    String? model,
    String? imagePath,
  }) => DreamEntry(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    transcript: transcript ?? this.transcript,
    explanation: explanation ?? this.explanation,
    reflection: reflection ?? this.reflection,
    symbolsJson: symbolsJson ?? this.symbolsJson,
    quotesJson: quotesJson ?? this.quotesJson,
    model: model ?? this.model,
    imagePath: imagePath ?? this.imagePath,
  );
  DreamEntry copyWithCompanion(DreamEntriesCompanion data) {
    return DreamEntry(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      reflection: data.reflection.present
          ? data.reflection.value
          : this.reflection,
      symbolsJson: data.symbolsJson.present
          ? data.symbolsJson.value
          : this.symbolsJson,
      quotesJson: data.quotesJson.present
          ? data.quotesJson.value
          : this.quotesJson,
      model: data.model.present ? data.model.value : this.model,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DreamEntry(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('transcript: $transcript, ')
          ..write('explanation: $explanation, ')
          ..write('reflection: $reflection, ')
          ..write('symbolsJson: $symbolsJson, ')
          ..write('quotesJson: $quotesJson, ')
          ..write('model: $model, ')
          ..write('imagePath: $imagePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    transcript,
    explanation,
    reflection,
    symbolsJson,
    quotesJson,
    model,
    imagePath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DreamEntry &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.transcript == this.transcript &&
          other.explanation == this.explanation &&
          other.reflection == this.reflection &&
          other.symbolsJson == this.symbolsJson &&
          other.quotesJson == this.quotesJson &&
          other.model == this.model &&
          other.imagePath == this.imagePath);
}

class DreamEntriesCompanion extends UpdateCompanion<DreamEntry> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<String> transcript;
  final Value<String> explanation;
  final Value<String> reflection;
  final Value<String> symbolsJson;
  final Value<String> quotesJson;
  final Value<String> model;
  final Value<String> imagePath;
  final Value<int> rowid;
  const DreamEntriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.transcript = const Value.absent(),
    this.explanation = const Value.absent(),
    this.reflection = const Value.absent(),
    this.symbolsJson = const Value.absent(),
    this.quotesJson = const Value.absent(),
    this.model = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DreamEntriesCompanion.insert({
    required String id,
    required DateTime createdAt,
    required String transcript,
    this.explanation = const Value.absent(),
    this.reflection = const Value.absent(),
    this.symbolsJson = const Value.absent(),
    this.quotesJson = const Value.absent(),
    this.model = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       transcript = Value(transcript);
  static Insertable<DreamEntry> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? transcript,
    Expression<String>? explanation,
    Expression<String>? reflection,
    Expression<String>? symbolsJson,
    Expression<String>? quotesJson,
    Expression<String>? model,
    Expression<String>? imagePath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (transcript != null) 'transcript': transcript,
      if (explanation != null) 'explanation': explanation,
      if (reflection != null) 'reflection': reflection,
      if (symbolsJson != null) 'symbols_json': symbolsJson,
      if (quotesJson != null) 'quotes_json': quotesJson,
      if (model != null) 'model': model,
      if (imagePath != null) 'image_path': imagePath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DreamEntriesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<String>? transcript,
    Value<String>? explanation,
    Value<String>? reflection,
    Value<String>? symbolsJson,
    Value<String>? quotesJson,
    Value<String>? model,
    Value<String>? imagePath,
    Value<int>? rowid,
  }) {
    return DreamEntriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      transcript: transcript ?? this.transcript,
      explanation: explanation ?? this.explanation,
      reflection: reflection ?? this.reflection,
      symbolsJson: symbolsJson ?? this.symbolsJson,
      quotesJson: quotesJson ?? this.quotesJson,
      model: model ?? this.model,
      imagePath: imagePath ?? this.imagePath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (reflection.present) {
      map['reflection'] = Variable<String>(reflection.value);
    }
    if (symbolsJson.present) {
      map['symbols_json'] = Variable<String>(symbolsJson.value);
    }
    if (quotesJson.present) {
      map['quotes_json'] = Variable<String>(quotesJson.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DreamEntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('transcript: $transcript, ')
          ..write('explanation: $explanation, ')
          ..write('reflection: $reflection, ')
          ..write('symbolsJson: $symbolsJson, ')
          ..write('quotesJson: $quotesJson, ')
          ..write('model: $model, ')
          ..write('imagePath: $imagePath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DreamEntriesTable dreamEntries = $DreamEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [dreamEntries];
}

typedef $$DreamEntriesTableCreateCompanionBuilder =
    DreamEntriesCompanion Function({
      required String id,
      required DateTime createdAt,
      required String transcript,
      Value<String> explanation,
      Value<String> reflection,
      Value<String> symbolsJson,
      Value<String> quotesJson,
      Value<String> model,
      Value<String> imagePath,
      Value<int> rowid,
    });
typedef $$DreamEntriesTableUpdateCompanionBuilder =
    DreamEntriesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<String> transcript,
      Value<String> explanation,
      Value<String> reflection,
      Value<String> symbolsJson,
      Value<String> quotesJson,
      Value<String> model,
      Value<String> imagePath,
      Value<int> rowid,
    });

class $$DreamEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DreamEntriesTable> {
  $$DreamEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reflection => $composableBuilder(
    column: $table.reflection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbolsJson => $composableBuilder(
    column: $table.symbolsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quotesJson => $composableBuilder(
    column: $table.quotesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DreamEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DreamEntriesTable> {
  $$DreamEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reflection => $composableBuilder(
    column: $table.reflection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbolsJson => $composableBuilder(
    column: $table.symbolsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quotesJson => $composableBuilder(
    column: $table.quotesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DreamEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DreamEntriesTable> {
  $$DreamEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reflection => $composableBuilder(
    column: $table.reflection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get symbolsJson => $composableBuilder(
    column: $table.symbolsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quotesJson => $composableBuilder(
    column: $table.quotesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);
}

class $$DreamEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DreamEntriesTable,
          DreamEntry,
          $$DreamEntriesTableFilterComposer,
          $$DreamEntriesTableOrderingComposer,
          $$DreamEntriesTableAnnotationComposer,
          $$DreamEntriesTableCreateCompanionBuilder,
          $$DreamEntriesTableUpdateCompanionBuilder,
          (
            DreamEntry,
            BaseReferences<_$AppDatabase, $DreamEntriesTable, DreamEntry>,
          ),
          DreamEntry,
          PrefetchHooks Function()
        > {
  $$DreamEntriesTableTableManager(_$AppDatabase db, $DreamEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DreamEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DreamEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DreamEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> transcript = const Value.absent(),
                Value<String> explanation = const Value.absent(),
                Value<String> reflection = const Value.absent(),
                Value<String> symbolsJson = const Value.absent(),
                Value<String> quotesJson = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DreamEntriesCompanion(
                id: id,
                createdAt: createdAt,
                transcript: transcript,
                explanation: explanation,
                reflection: reflection,
                symbolsJson: symbolsJson,
                quotesJson: quotesJson,
                model: model,
                imagePath: imagePath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required String transcript,
                Value<String> explanation = const Value.absent(),
                Value<String> reflection = const Value.absent(),
                Value<String> symbolsJson = const Value.absent(),
                Value<String> quotesJson = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DreamEntriesCompanion.insert(
                id: id,
                createdAt: createdAt,
                transcript: transcript,
                explanation: explanation,
                reflection: reflection,
                symbolsJson: symbolsJson,
                quotesJson: quotesJson,
                model: model,
                imagePath: imagePath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DreamEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DreamEntriesTable,
      DreamEntry,
      $$DreamEntriesTableFilterComposer,
      $$DreamEntriesTableOrderingComposer,
      $$DreamEntriesTableAnnotationComposer,
      $$DreamEntriesTableCreateCompanionBuilder,
      $$DreamEntriesTableUpdateCompanionBuilder,
      (
        DreamEntry,
        BaseReferences<_$AppDatabase, $DreamEntriesTable, DreamEntry>,
      ),
      DreamEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DreamEntriesTableTableManager get dreamEntries =>
      $$DreamEntriesTableTableManager(_db, _db.dreamEntries);
}
