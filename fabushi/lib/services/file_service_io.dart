import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import './abstract_file_service.dart';
import 'package:flutter/material.dart';

class FileService implements AbstractFileService {
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
    return true;
  }

  @override
  Future<List<PlatformFile>> pickFiles() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      debugPrint('存储权限被拒绝');
      return [];
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        dialogTitle: '请选择要发送的文件',
        withData: true, // 确保加载文件数据到内存
        withReadStream: true, // 支持流式读取
      );

      if (result != null && result.files.isNotEmpty) {
        debugPrint('已选择 ${result.files.length} 个文件:');
        for (var file in result.files) {
          debugPrint(
            '- ${file.name} (${file.size} 字节)${file.path != null ? ", 路径: ${file.path}" : ""}',
          );
        }
      } else {
        debugPrint('未选择任何文件');
      }

      return result?.files ?? [];
    } catch (e) {
      debugPrint('选择文件时发生错误: $e');
      return [];
    }
  }

  @override
  Future<void> releaseFiles(List<PlatformFile> files) async {
    // 在IO平台上，文件句柄由操作系统管理，不需要手动释放。
    for (var file in files) {
      if (file.path != null && file.path!.isNotEmpty) {
        try {
          // 这里不需要特殊处理，只是为了满足接口要求
          debugPrint('释放文件: ${file.name}');
        } catch (e) {
          debugPrint('释放文件时发生错误: $e');
        }
      }
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
    if (file.bytes != null) {
      return file.bytes!;
    }

    if (file.path == null || file.path!.isEmpty) {
      throw Exception('文件路径为空');
    }

    final fileObj = File(file.path!);
    if (!fileObj.existsSync()) {
      throw Exception('文件不存在: ${file.path}');
    }

    return await fileObj.readAsBytes();
  }

  Future<File> createTempFile(String content, {String suffix = '.tmp'}) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}$suffix');
    await tempFile.writeAsString(content);
    return tempFile;
  }

  Future<void> deleteTempFile(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
