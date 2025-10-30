import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart';
import '../database/search_database.dart';

class TextIndexer {
  final SearchDatabase db;

  TextIndexer(this.db);

  Future<void> indexAssets() async {
    await db.clearAll();
    
    try {
      final manifestJson = await rootBundle.loadString('assets/data/asset-manifest.json');
      final List<dynamic> manifest = json.decode(manifestJson);
      
      int indexed = 0;
      int failed = 0;
      const maxFiles = 200;
      
      for (final item in manifest) {
        if (indexed >= maxFiles) break;
        
        var path = item['key'] as String;
        if (path.endsWith('.txt')) {
          if (path.startsWith('assets/')) {
            path = path.substring(7);
          }
          
          try {
            final content = await rootBundle.loadString(path);
            final title = path.split('/').last.replaceAll('.txt', '');
            final parts = path.split('/');
            final category = parts.length > 1 ? parts[parts.length - 2] : '其他';
            
            await db.insertText(TextContentsCompanion(
              title: Value(title),
              content: Value(content),
              filePath: Value(path),
              category: Value(category),
            ));
            indexed++;
          } catch (e) {
            failed++;
            if (failed > 100) break;
          }
        }
      }
      debugPrint('✅ 总计索引 $indexed 个文件，失败 $failed 个');
    } catch (e) {
      debugPrint('❌ 索引失败: $e');
    }
  }
}
