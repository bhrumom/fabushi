import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/unified_config.dart';

// 定义素材服务器的基地址
// const String _baseUrl = 'https://fabushi-flutter-web.workers.dev';

class AssetScreen extends StatefulWidget {
  @override
  _AssetScreenState createState() => _AssetScreenState();
}

class _AssetScreenState extends State<AssetScreen> {
  Map<String, List<Map<String, dynamic>>> _assetGroups = {};
  bool _isLoading = true;
  String? _error;
  Set<String> _downloadingAssets = {};
  Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(Uri.parse('${UnifiedConfig.currentBackendUrl}/api/assets/list'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final files = List<Map<String, dynamic>>.from(data['files']);
        
        // 按目录分组
        final Map<String, List<Map<String, dynamic>>> groups = {};
        for (var fileInfo in files) {
          String key = fileInfo['key'];
          if (key.contains('/')) {
            final parts = key.split('/');
            final dir = parts[0];
            final fileName = parts.sublist(1).join('/');
            
            if (!groups.containsKey(dir)) {
              groups[dir] = [];
            }
            groups[dir]!.add({
              'name': fileName,
              'source': fileInfo['source'],
              'key': key,
            });
          }
        }

        setState(() {
          _assetGroups = groups;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load assets: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      print(e);
    }
  }

  Future<void> _downloadAsset(Map<String, dynamic> assetInfo) async {
    final String assetPath = assetInfo['key'];
    final String fileName = assetInfo['name'];
    final String source = assetInfo['source'];

    if (_downloadingAssets.contains(assetPath)) return;

    setState(() {
      _downloadingAssets.add(assetPath);
      _downloadProgress[assetPath] = 0.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('开始下载 $fileName')),
    );

    try {
      if (!kIsWeb) {
        if (Platform.isAndroid || Platform.isIOS) {
          var status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('存储权限被拒绝');
          }
        }
      }

      final String url;
      if (source == 'r2') {
        url = '${UnifiedConfig.currentBackendUrl}/r2?file=${Uri.encodeComponent(assetPath)}';
      } else { // 'static'
        url = '${UnifiedConfig.currentBackendUrl}/$assetPath';
      }
      
      final request = http.Request('GET', Uri.parse(url));
      final http.StreamedResponse response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('下载失败: ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      List<int> bytes = [];
      int receivedBytes = 0;

      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        receivedBytes += chunk.length;
        if (contentLength != null) {
          setState(() {
            _downloadProgress[assetPath] = receivedBytes / contentLength;
          });
        }
      }
      
      final Directory? dir;
      if (kIsWeb) {
        // Web平台无法直接保存文件，这里仅作演示
        print("Web平台下载完成，大小: ${bytes.length} bytes");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName 已在内存中准备好 (Web)')),
        );
      } else {
        if (Platform.isAndroid) {
          dir = await getExternalStorageDirectory();
        } else {
          dir = await getApplicationDocumentsDirectory();
        }
        
        if (dir == null) {
          throw Exception("无法获取下载目录");
        }

        final filePath = '${dir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName 已下载到: ${dir.path}')),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载 $fileName 失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _downloadingAssets.remove(assetPath);
        _downloadProgress.remove(assetPath);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('内置素材'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchAssets,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error', style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAssets,
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_assetGroups.isEmpty) {
      return Center(child: Text('没有找到任何素材。'));
    }

    return ListView.builder(
      itemCount: _assetGroups.keys.length,
      itemBuilder: (context, index) {
        final dir = _assetGroups.keys.elementAt(index);
        final files = _assetGroups[dir]!;
        return ExpansionTile(
          title: Text(dir, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          children: files.map((assetInfo) {
            final String assetPath = assetInfo['key'];
            final String fileName = assetInfo['name'];
            final isDownloading = _downloadingAssets.contains(assetPath);
            final progress = _downloadProgress[assetPath];

            return ListTile(
              title: Text(fileName),
              trailing: isDownloading
                  ? SizedBox(
                      width: 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('${((progress ?? 0) * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.download),
                      onPressed: () => _downloadAsset(assetInfo),
                    ),
            );
          }).toList(),
        );
      },
    );
  }
}

