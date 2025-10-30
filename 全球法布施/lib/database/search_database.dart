import 'package:drift/drift.dart';
import 'package:drift/web.dart';

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
  
  static QueryExecutor _openConnection() {
    return WebDatabase('search_db');
  }

  Future<List<TextContent>> searchTexts(String query) async {
    return (select(textContents)
          ..where((t) => 
              t.title.like('%$query%') | 
              t.content.like('%$query%')))
        .get();
  }

  Future<int> insertText(TextContentsCompanion entry) => 
      into(textContents).insert(entry);

  Future<void> clearAll() => delete(textContents).go();
}
