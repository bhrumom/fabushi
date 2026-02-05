import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import './abstract_file_service.dart';
import 'package:flutter/material.dart';

class FileService implements AbstractFileService {
  @override
  Future<List<PlatformFile>> pickFiles() async {
    try {
      debugPrint('📱 开始选择文件...');
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true, // 在Web上必须为true才能获取文件字节
        dialogTitle: '请选择要发送的文件',
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        debugPrint('✅ 成功选择 ${result.files.length} 个文件');
        for (var file in result.files) {
          debugPrint('  - ${file.name} (${getFileSizeString(file.size)})');
        }
      } else {
        debugPrint('⚠️ 未选择任何文件');
      }

      return result?.files ?? [];
    } catch (e) {
      debugPrint('❌ 在Web上选择文件时出错: $e');
      return [];
    }
  }

  @override
  Future<void> releaseFiles(List<PlatformFile> files) async {
    // 在Web上，文件数据在内存中，当不再被引用时由垃圾回收器处理。
    // 不需要手动释放。
    for (var file in files) {
      debugPrint('Web平台释放文件: ${file.name}');
    }
    return;
  }

  // 实用方法
  String getFileType(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return 'unknown';
  }

  String getFileSizeString(int sizeInBytes) {
    final kb = sizeInBytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(2)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(2)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  Future<Uint8List> readFileBytes(PlatformFile file) async {
    if (file.bytes == null) {
      throw Exception('无法在Web平台上获取文件字节数据');
    }
    return file.bytes!;
  }
}
