// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_database.dart';

// ignore_for_file: type=lint
class $TextContentsTable extends TextContents
    with TableInfo<$TextContentsTable, TextContent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TextContentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, content, filePath, category];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'text_contents';
  @override
  VerificationContext validateIntegrity(Insertable<TextContent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TextContent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TextContent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
    );
  }

  @override
  $TextContentsTable createAlias(String alias) {
    return $TextContentsTable(attachedDatabase, alias);
  }
}

class TextContent extends DataClass implements Insertable<TextContent> {
  final int id;
  final String title;
  final String content;
  final String filePath;
  final String category;
  const TextContent(
      {required this.id,
      required this.title,
      required this.content,
      required this.filePath,
      required this.category});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['file_path'] = Variable<String>(filePath);
    map['category'] = Variable<String>(category);
    return map;
  }

  TextContentsCompanion toCompanion(bool nullToAbsent) {
    return TextContentsCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      filePath: Value(filePath),
      category: Value(category),
    );
  }

  factory TextContent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TextContent(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      filePath: serializer.fromJson<String>(json['filePath']),
      category: serializer.fromJson<String>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'filePath': serializer.toJson<String>(filePath),
      'category': serializer.toJson<String>(category),
    };
  }

  TextContent copyWith(
          {int? id,
          String? title,
          String? content,
          String? filePath,
          String? category}) =>
      TextContent(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        filePath: filePath ?? this.filePath,
        category: category ?? this.category,
      );
  TextContent copyWithCompanion(TextContentsCompanion data) {
    return TextContent(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TextContent(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('filePath: $filePath, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, content, filePath, category);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextContent &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.filePath == this.filePath &&
          other.category == this.category);
}

class TextContentsCompanion extends UpdateCompanion<TextContent> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> content;
  final Value<String> filePath;
  final Value<String> category;
  const TextContentsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.filePath = const Value.absent(),
    this.category = const Value.absent(),
  });
  TextContentsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String content,
    required String filePath,
    required String category,
  })  : title = Value(title),
        content = Value(content),
        filePath = Value(filePath),
        category = Value(category);
  static Insertable<TextContent> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? filePath,
    Expression<String>? category,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (filePath != null) 'file_path': filePath,
      if (category != null) 'category': category,
    });
  }

  TextContentsCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String>? content,
      Value<String>? filePath,
      Value<String>? category}) {
    return TextContentsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      filePath: filePath ?? this.filePath,
      category: category ?? this.category,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TextContentsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('filePath: $filePath, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }
}

abstract class _$SearchDatabase extends GeneratedDatabase {
  _$SearchDatabase(QueryExecutor e) : super(e);
  $SearchDatabaseManager get managers => $SearchDatabaseManager(this);
  late final $TextContentsTable textContents = $TextContentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [textContents];
}

typedef $$TextContentsTableCreateCompanionBuilder = TextContentsCompanion
    Function({
  Value<int> id,
  required String title,
  required String content,
  required String filePath,
  required String category,
});
typedef $$TextContentsTableUpdateCompanionBuilder = TextContentsCompanion
    Function({
  Value<int> id,
  Value<String> title,
  Value<String> content,
  Value<String> filePath,
  Value<String> category,
});

class $$TextContentsTableFilterComposer
    extends Composer<_$SearchDatabase, $TextContentsTable> {
  $$TextContentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));
}

class $$TextContentsTableOrderingComposer
    extends Composer<_$SearchDatabase, $TextContentsTable> {
  $$TextContentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));
}

class $$TextContentsTableAnnotationComposer
    extends Composer<_$SearchDatabase, $TextContentsTable> {
  $$TextContentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);
}

class $$TextContentsTableTableManager extends RootTableManager<
    _$SearchDatabase,
    $TextContentsTable,
    TextContent,
    $$TextContentsTableFilterComposer,
    $$TextContentsTableOrderingComposer,
    $$TextContentsTableAnnotationComposer,
    $$TextContentsTableCreateCompanionBuilder,
    $$TextContentsTableUpdateCompanionBuilder,
    (
      TextContent,
      BaseReferences<_$SearchDatabase, $TextContentsTable, TextContent>
    ),
    TextContent,
    PrefetchHooks Function()> {
  $$TextContentsTableTableManager(_$SearchDatabase db, $TextContentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TextContentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TextContentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TextContentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String> category = const Value.absent(),
          }) =>
              TextContentsCompanion(
            id: id,
            title: title,
            content: content,
            filePath: filePath,
            category: category,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            required String content,
            required String filePath,
            required String category,
          }) =>
              TextContentsCompanion.insert(
            id: id,
            title: title,
            content: content,
            filePath: filePath,
            category: category,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TextContentsTableProcessedTableManager = ProcessedTableManager<
    _$SearchDatabase,
    $TextContentsTable,
    TextContent,
    $$TextContentsTableFilterComposer,
    $$TextContentsTableOrderingComposer,
    $$TextContentsTableAnnotationComposer,
    $$TextContentsTableCreateCompanionBuilder,
    $$TextContentsTableUpdateCompanionBuilder,
    (
      TextContent,
      BaseReferences<_$SearchDatabase, $TextContentsTable, TextContent>
    ),
    TextContent,
    PrefetchHooks Function()>;

class $SearchDatabaseManager {
  final _$SearchDatabase _db;
  $SearchDatabaseManager(this._db);
  $$TextContentsTableTableManager get textContents =>
      $$TextContentsTableTableManager(_db, _db.textContents);
}
