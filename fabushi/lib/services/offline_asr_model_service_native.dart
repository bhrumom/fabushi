import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/config/app_config.dart';

enum OfflineAsrModelStatus {
  unknown,
  notInstalled,
  downloading,
  installed,
  error,
}

class OfflineAsrModelFile {
  final String name;
  final String url;
  final String? sha256;
  final int minBytes;

  const OfflineAsrModelFile({
    required this.name,
    required this.url,
    this.sha256,
    this.minBytes = 1024,
  });

  factory OfflineAsrModelFile.fromJson(Map<String, dynamic> json) {
    return OfflineAsrModelFile(
      name: json['name'].toString(),
      url: json['url'].toString(),
      sha256: json['sha256']?.toString(),
      minBytes: json['minBytes'] is int ? json['minBytes'] as int : 1024,
    );
  }
}

class OfflineAsrModelManifest {
  final String id;
  final String version;
  final List<OfflineAsrModelFile> files;

  const OfflineAsrModelManifest({
    required this.id,
    required this.version,
    required this.files,
  });

  factory OfflineAsrModelManifest.fromJson(Map<String, dynamic> json) {
    final files = (json['files'] as List<dynamic>? ?? [])
        .map(
          (item) => OfflineAsrModelFile.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return OfflineAsrModelManifest(
      id: json['id']?.toString() ?? 'streaming-paraformer-zh-en',
      version: json['version']?.toString() ?? '1',
      files: files,
    );
  }
}

class OfflineAsrModelService extends ChangeNotifier {
  static OfflineAsrModelService? _instance;
  static OfflineAsrModelService get instance =>
      _instance ??= OfflineAsrModelService._();
  OfflineAsrModelService._();

  OfflineAsrModelStatus _status = OfflineAsrModelStatus.unknown;
  double _progress = 0;
  String _statusMessage = '尚未检查离线语音模型';

  OfflineAsrModelStatus get status => _status;
  double get progress => _progress;
  String get statusMessage => _statusMessage;

  static const _modelId = 'streaming-paraformer-zh-en';
  static const _requiredFiles = [
    'encoder.int8.onnx',
    'decoder.int8.onnx',
    'tokens.txt',
  ];

  Future<Directory> _modelDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/sherpa-onnx-models/$_modelId');
  }

  Future<bool> refreshStatus() async {
    final dir = await _modelDirectory();
    final installed = await _isInstalled(dir);
    _status = installed
        ? OfflineAsrModelStatus.installed
        : OfflineAsrModelStatus.notInstalled;
    _progress = installed ? 1 : 0;
    _statusMessage = installed ? '离线语音模型已就绪' : '请先下载离线语音模型';
    notifyListeners();
    return installed;
  }

  Future<String?> getInstalledModelDir() async {
    final dir = await _modelDirectory();
    if (await _isInstalled(dir)) return dir.path;
    await refreshStatus();
    return null;
  }

  Future<String?> downloadModel() async {
    final manifest = await _loadManifest();
    final dir = await _modelDirectory();
    await dir.create(recursive: true);

    _status = OfflineAsrModelStatus.downloading;
    _progress = 0;
    _statusMessage = '正在下载离线语音模型...';
    notifyListeners();

    try {
      for (var i = 0; i < manifest.files.length; i++) {
        final file = manifest.files[i];
        final target = File('${dir.path}/${file.name}');
        await _downloadFile(file, target);
        final baseProgress = (i + 1) / manifest.files.length;
        _progress = baseProgress.clamp(0, 1);
        _statusMessage = '离线语音模型下载中 ${(_progress * 100).round()}%';
        notifyListeners();
      }

      if (!await _isInstalled(dir)) {
        throw StateError('模型文件不完整');
      }

      _status = OfflineAsrModelStatus.installed;
      _progress = 1;
      _statusMessage = '离线语音模型已就绪';
      notifyListeners();
      return dir.path;
    } catch (e) {
      _status = OfflineAsrModelStatus.error;
      _statusMessage = '离线语音模型下载失败: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> clearModel() async {
    final dir = await _modelDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await refreshStatus();
  }

  Future<OfflineAsrModelManifest> _loadManifest() async {
    final manifestUri = AppConfig.buildBackendUri(
      '/api/meditation/asr-model-manifest',
    );

    try {
      final response = await http
          .get(manifestUri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return OfflineAsrModelManifest.fromJson(
          Map<String, dynamic>.from(jsonDecode(response.body) as Map),
        );
      }
    } catch (e) {
      debugPrint('[OfflineAsrModel] 使用默认 manifest: $e');
    }

    return _fallbackManifest();
  }

  OfflineAsrModelManifest _fallbackManifest() {
    String r2Url(String fileName) {
      final key = 'asr-models/$_modelId/$fileName';
      return AppConfig.buildBackendUrl('/r2', queryParameters: {'file': key});
    }

    return OfflineAsrModelManifest(
      id: _modelId,
      version: 'fallback',
      files: [
        OfflineAsrModelFile(
          name: 'encoder.int8.onnx',
          url: r2Url('encoder.int8.onnx'),
          minBytes: 1024 * 1024,
        ),
        OfflineAsrModelFile(
          name: 'decoder.int8.onnx',
          url: r2Url('decoder.int8.onnx'),
          minBytes: 1024 * 512,
        ),
        OfflineAsrModelFile(
          name: 'tokens.txt',
          url: r2Url('tokens.txt'),
          minBytes: 1024,
        ),
      ],
    );
  }

  Future<void> _downloadFile(OfflineAsrModelFile modelFile, File target) async {
    final request = http.Request('GET', Uri.parse(modelFile.url));
    final response = await request.send().timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}: ${modelFile.name}');
    }

    final temp = File('${target.path}.downloading');
    final sink = temp.openWrite();
    final digestSink = AccumulatorSink<Digest>();
    final byteSink = sha256.startChunkedConversion(digestSink);
    var received = 0;

    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        byteSink.add(chunk);
      }
    } finally {
      await sink.close();
      byteSink.close();
    }

    if (received < modelFile.minBytes) {
      if (await temp.exists()) {
        await temp.delete();
      }
      throw StateError('${modelFile.name} 文件过小');
    }

    final expectedSha = modelFile.sha256;
    if (expectedSha != null && expectedSha.isNotEmpty) {
      final actualSha = digestSink.events.single.toString();
      if (actualSha.toLowerCase() != expectedSha.toLowerCase()) {
        if (await temp.exists()) {
          await temp.delete();
        }
        throw StateError('${modelFile.name} 校验失败');
      }
    }

    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  Future<bool> _isInstalled(Directory dir) async {
    for (final fileName in _requiredFiles) {
      final file = File('${dir.path}/$fileName');
      if (!await file.exists()) return false;
      final minSize = fileName.endsWith('.onnx') ? 1024 * 512 : 1024;
      if (await file.length() < minSize) return false;
    }
    return true;
  }
}

class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];

  @override
  void add(T data) => events.add(data);

  @override
  void close() {}
}
