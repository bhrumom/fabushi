import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'search_database.g.dart';

class TextContents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get filePath => text()();
  TextColumn get category => text()();
}

@DriftDatabase(tables: [TextContents])
class SearchDatabase extends _$SearchDatabase {
  SearchDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'search_db.sqlite'));
      return NativeDatabase(file);
    });
  }

  Future<List<TextContent>> searchTexts(String query) async {
    return (select(
      textContents,
    )..where((t) => t.title.like('%$query%') | t.content.like('%$query%'))).get();
  }

  Future<int> insertText(TextContentsCompanion entry) => into(textContents).insert(entry);

  Future<void> clearAll() => delete(textContents).go();
}
