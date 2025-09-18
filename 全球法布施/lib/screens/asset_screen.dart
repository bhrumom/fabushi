import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:convert' as convert;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/unified_config.dart';
import '../services/downloaded_assets_service.dart';

// 导入Web平台特定的包
import 'package:universal_html/html.dart' as html;

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
  List<Map<String, dynamic>> _treeAssets = []; // 法宝树素材列表
  Set<String> _selectedAssets = {}; // 用户选择的素材
  final DownloadedAssetsService _downloadedAssetsService = DownloadedAssetsService();
  
  // 高能素材相关
  Map<String, List<Map<String, dynamic>>> _highEnergyAssetGroups = {};
  List<Map<String, dynamic>> _highEnergyTreeAssets = [];
  bool _showHighEnergyAssets = false; // 是否显示高能素材

  @override
  void initState() {
    super.initState();
    print('当前平台: ${kIsWeb ? "Web" : "非Web"}');
    print('素材来源: 本地资源文件');
    
    // 初始化已下载素材服务
    _initializeDownloadedAssetsService();
  }

  /// 初始化已下载素材服务
  Future<void> _initializeDownloadedAssetsService() async {
    await _downloadedAssetsService.initialize();
    // 所有平台都从本地加载素材列表
    _loadLocalAssets();
    // 加载本地R2文件列表，无需查询即可查看
    _loadLocalR2FilesList();
  }

  // 获取法宝树素材列表（仅用于展示，不实际下载）
  Future<void> _fetchTreeAssets() async {
  // 所有平台都从本地加载素材列表，不再从网络获取
  await _loadLocalAssets();
  
  // 如果需要树形结构，可以在这里对本地素材列表进行转换
  // 目前保持与之前相同的平面结构
}

  // 从本地加载素材列表
  Future<void> _loadLocalAssets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // 从本地资源文件加载素材列表
      final String manifestString = await rootBundle.loadString('assets/data/asset-manifest.json');
      final List<dynamic> files = json.decode(manifestString);
      
      print('从本地加载的文件数量: ${files.length}');
      
      // 按目录分组 - 支持多级目录结构
      final Map<String, List<Map<String, dynamic>>> groups = {};
      final List<Map<String, dynamic>> treeAssets = [];
      
      for (var fileInfo in files) {
        String key = fileInfo['key'];
        
        // 过滤掉JSON文件和隐藏文件（如.DS_Store）
        if (key.toLowerCase().endsWith('.json') || key.contains('/.DS_Store') || key.startsWith('.')) {
          continue;
        }
        
        if (key.contains('/')) {
          final parts = key.split('/');
          
          // 构建多级目录结构
          String currentPath = '';
          for (int i = 0; i < parts.length - 1; i++) {
            final dir = parts[i];
            if (i > 0) {
              currentPath += '/';
            }
            currentPath += dir;
            
            final fullPath = currentPath;
            final fileName = parts.sublist(i + 1).join('/');
            
            // 只在最后一层添加文件
            if (i == parts.length - 2) {
              if (!groups.containsKey(fullPath)) {
                groups[fullPath] = [];
              }
              
              final assetInfo = {
                'name': fileName,
                'source': fileInfo['source'],
                'key': key,
                'directory': fullPath,
              };
              
              groups[fullPath]!.add(assetInfo);
              treeAssets.add(assetInfo);
            }
          }
        }
      }

      print('分组后的目录数量: ${groups.length}');
      print('素材总数: ${treeAssets.length}');

      setState(() {
        _assetGroups = groups;
        _treeAssets = treeAssets;
        _isLoading = false;
      });
      
    } catch (e) {
      print('从本地加载素材失败: $e');
      setState(() {
        _isLoading = false;
        _error = '从本地加载素材失败: $e';
      });
    }
  }

  // 加载本地R2文件列表（无需查询即可查看）
  Future<void> _loadLocalR2FilesList() async {
    try {
      // 从本地资源文件加载R2文件列表
      final String r2FilesString = await rootBundle.loadString('assets/data/r2-files-list.json');
      final Map<String, dynamic> r2Data = json.decode(r2FilesString);
      
      // 获取文件列表（兼容objects和files字段）
      final List<dynamic> files = r2Data['objects'] ?? r2Data['files'] ?? [];
      
      print('从本地加载的R2文件数量: ${files.length}');
      
      // 按目录分组 - R2文件都在根目录，统一放入一个分组
      final Map<String, List<Map<String, dynamic>>> groups = {};
      final List<Map<String, dynamic>> treeAssets = [];
      
      for (var fileInfo in files) {
        String key = fileInfo['key'];
        
        // 过滤掉JSON文件和隐藏文件（如.DS_Store）
        if (key.toLowerCase().endsWith('.json') || key.contains('/.DS_Store') || key.startsWith('.')) {
          continue;
        }
        
        // R2存储桶中的文件统一放入"R2存储桶文件"分组
        const String directory = 'R2存储桶文件';
        final assetInfo = {
          'name': key, // 文件名就是key
          'source': 'r2', // R2存储桶中的文件
          'key': key,
          'directory': directory,
          'description': fileInfo['key'] ?? '', // 使用key作为描述
          'size': fileInfo['size'] ?? 0,
          'uploaded': fileInfo['uploaded'], // R2特有的上传时间
          'isDownloaded': false, // 标记是否已下载
        };
        
        if (!groups.containsKey(directory)) {
          groups[directory] = [];
        }
        
        groups[directory]!.add(assetInfo);
        treeAssets.add(assetInfo);
      }

      print('R2文件分组后的目录数量: ${groups.length}');
      print('R2文件总数: ${treeAssets.length}');

      setState(() {
        _highEnergyAssetGroups = groups;
        _highEnergyTreeAssets = treeAssets;
      });
      
      print('本地R2文件列表加载完成');
    } catch (e) {
      print('加载本地R2文件列表失败: $e');
      // 如果加载失败，保持高能素材为空，不影响主功能
      setState(() {
        _highEnergyAssetGroups = {};
        _highEnergyTreeAssets = [];
      });
    }
  }

  // 查询R2存储桶中的文件列表（手动触发）
  Future<void> _queryR2Files() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // 从R2存储桶获取实际文件列表
      final String baseUrl = UnifiedConfig.isProduction ? UnifiedConfig.cloudflareWorkerProdUrl : UnifiedConfig.cloudflareWorkerDevUrl;
      final String url = '$baseUrl/r2?list';
      
      print('查询R2存储桶文件列表: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('获取R2文件列表失败: ${response.statusCode}');
      }
      
      final data = json.decode(response.body);
      final List<dynamic> files = data['files'] ?? data['objects'] ?? [];
      
      print('从R2存储桶获取的文件数量: ${files.length}');
      
      // 按目录分组 - R2文件都在根目录，统一放入一个分组
      final Map<String, List<Map<String, dynamic>>> groups = {};
      final List<Map<String, dynamic>> treeAssets = [];
      
      for (var fileInfo in files) {
        String key = fileInfo['key'];
        
        // 过滤掉JSON文件和隐藏文件（如.DS_Store）
        if (key.toLowerCase().endsWith('.json') || key.contains('/.DS_Store') || key.startsWith('.')) {
          continue;
        }
        
        // R2存储桶中的文件统一放入“R2存储桶文件”分组
        const String directory = 'R2存储桶文件';
        final assetInfo = {
          'name': key, // 文件名就是key
          'source': 'r2', // R2存储桶中的文件
          'key': key,
          'directory': directory,
          'description': fileInfo['key'] ?? '', // 使用key作为描述
          'size': fileInfo['size'] ?? 0,
          'uploaded': fileInfo['uploaded'], // R2特有的上传时间
          'isDownloaded': false, // 标记是否已下载
        };
        
        if (!groups.containsKey(directory)) {
          groups[directory] = [];
        }
        
        groups[directory]!.add(assetInfo);
        treeAssets.add(assetInfo);
      }

      print('R2文件分组后的目录数量: ${groups.length}');
      print('R2文件总数: ${treeAssets.length}');

      setState(() {
        _highEnergyAssetGroups = groups;
        _highEnergyTreeAssets = treeAssets;
        _isLoading = false;
      });
      
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功获取 ${files.length} 个R2文件')),
      );
      
    } catch (e) {
      print('查询R2存储桶文件失败: $e');
      setState(() {
        _isLoading = false;
        _error = '查询R2存储桶文件失败: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('查询R2文件失败: $e')),
      );
    }
  }

  // Web平台文件保存方法
  Future<void> _saveFileForWeb(String fileName, List<int> bytes) async {
    if (!kIsWeb) return;
    
    try {
      // 使用Web的本地存储API保存文件
      // 这里使用localStorage来保存文件信息，实际文件数据可以使用IndexedDB
      final fileData = {
        'name': fileName,
        'size': bytes.length,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': convert.base64.encode(bytes), // 将文件数据转换为base64字符串存储
      };
      
      // 获取已保存的文件列表
      final savedFilesStr = html.window.localStorage['saved_files'] ?? '[]';
      final List<dynamic> savedFiles = json.decode(savedFilesStr);
      
      // 检查是否已存在同名文件，如果存在则替换
      int existingIndex = savedFiles.indexWhere((f) => f['name'] == fileName);
      if (existingIndex >= 0) {
        savedFiles[existingIndex] = fileData;
      } else {
        savedFiles.add(fileData);
      }
      
      // 保存更新后的文件列表
      html.window.localStorage['saved_files'] = json.encode(savedFiles);
      
      // 保存文件数据到单独的存储项
      html.window.localStorage['file_$fileName'] = fileData['data'].toString();
      
      print('Web平台文件保存成功: $fileName, 大小: ${bytes.length} bytes');
    } catch (e) {
      print('Web平台文件保存失败: $e');
      throw Exception('Web平台文件保存失败: $e');
    }
  }

  // 从Web平台存储读取文件数据
  List<int>? _readFileDataFromWeb(String fileName) {
    if (!kIsWeb) return null;
    
    try {
      final fileDataStr = html.window.localStorage['file_$fileName'];
      if (fileDataStr == null) return null;
      
      return convert.base64.decode(fileDataStr);
    } catch (e) {
      print('读取Web平台文件失败: $e');
      return null;
    }
  }

  // 获取Web平台已保存的文件列表
  List<Map<String, dynamic>> _getSavedFilesForWeb() {
    if (!kIsWeb) return [];
    
    try {
      final savedFilesStr = html.window.localStorage['saved_files'] ?? '[]';
      final List<dynamic> savedFiles = json.decode(savedFilesStr);
      
      return savedFiles.map((f) => {
        'name': f['name'],
        'size': f['size'],
        'timestamp': f['timestamp'],
      }).toList();
    } catch (e) {
      print('获取Web平台已保存文件失败: $e');
      return [];
    }
  }

  // 从Web平台存储中读取文件数据
  List<int>? _readFileForWeb(String fileName) {
    if (!kIsWeb) return null;
    
    try {
      final fileDataStr = html.window.localStorage['file_$fileName'];
      if (fileDataStr == null) return null;
      
      return convert.base64.decode(fileDataStr);
    } catch (e) {
      print('读取Web平台文件失败: $e');
      return null;
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
      // 所有平台统一使用Cloudflare Worker下载素材，确保素材来源一致
      final String baseUrl = UnifiedConfig.isProduction ? UnifiedConfig.cloudflareWorkerProdUrl : UnifiedConfig.cloudflareWorkerDevUrl;
      
      if (source == 'r2') {
        url = '$baseUrl/r2?file=${Uri.encodeComponent(assetPath)}';
      } else { // 'static'
        url = '$baseUrl/$assetPath';
      }
      
      print('从以下URL下载素材: $url');
      
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
        // Web平台使用IndexedDB或浏览器存储来保存文件
        // 这里使用html包来实现Web平台的文件保存
        print("Web平台下载完成，大小: ${bytes.length} bytes");
        
        // 保存文件到浏览器的IndexedDB或本地存储
        // 这里使用简单的实现，实际项目中可能需要更复杂的存储逻辑
        await _saveFileForWeb(fileName, bytes);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName 已保存到Web应用存储')),
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

  // 确认选择素材并返回
  void _confirmSelection() {
    if (_selectedAssets.isEmpty) return;
    
    // 将选中的素材信息传递回上一个页面
    Navigator.pop(context, _selectedAssets.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showHighEnergyAssets ? '高能素材列表' : '素材列表'),
        actions: [
          IconButton(
            icon: Icon(_showHighEnergyAssets ? Icons.arrow_back : Icons.bolt),
            onPressed: () {
              setState(() {
                _showHighEnergyAssets = !_showHighEnergyAssets;
              });
            },
            tooltip: _showHighEnergyAssets ? '返回普通素材' : '查看高能素材',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : () {
              if (_showHighEnergyAssets) {
                _queryR2Files();
              } else {
                _loadLocalAssets();
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && !_showHighEnergyAssets) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null && !_showHighEnergyAssets) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error', style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLocalAssets,
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    // 根据当前模式选择要显示的素材
    final currentAssetGroups = _showHighEnergyAssets ? _highEnergyAssetGroups : _assetGroups;
    final currentTreeAssets = _showHighEnergyAssets ? _highEnergyTreeAssets : _treeAssets;

    if (currentAssetGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_showHighEnergyAssets ? '暂无高能素材' : '没有找到任何素材。'),
            if (_showHighEnergyAssets) ...[
              SizedBox(height: 20),
              Text('R2文件列表已本地加载，无需查询即可查看'),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _queryR2Files,
                icon: Icon(Icons.refresh),
                label: Text('刷新R2文件列表'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // 所有平台都使用相同的UI逻辑：显示素材列表，可以选择发送
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _showHighEnergyAssets ? '高能素材列表' : '素材列表',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            _showHighEnergyAssets 
              ? '选择高能素材，这些素材具有更强的加持力和功德'
              : '选择您需要的素材，点击"选择发送"后将自动从云端服务器下载',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: currentAssetGroups.keys.length,
            itemBuilder: (context, index) {
              final dir = currentAssetGroups.keys.elementAt(index);
              final files = currentAssetGroups[dir]!;
              
              // 提取目录名称（显示最后一级目录）
              final dirName = dir.contains('/') ? dir.split('/').last : dir;
              
              return ExpansionTile(
                title: Text(dirName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: dir.contains('/') ? Text(dir, style: TextStyle(fontSize: 12, color: Colors.grey)) : null,
                children: files.map((assetInfo) {
                  final String assetPath = assetInfo['key'];
                  final String fileName = assetInfo['name'];
                  final bool isSelected = _selectedAssets.contains(assetPath);
                  final String? description = assetInfo['description'];

                  return CheckboxListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(fileName)),
                        if (_downloadedAssetsService.isAssetDownloaded(assetPath))
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_downloadedAssetsService.isAssetDownloaded(assetPath)) 
                          Text('已下载', style: TextStyle(color: Colors.green, fontSize: 12)),
                        if (description != null && description.isNotEmpty)
                          Text(description, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedAssets.add(assetPath);
                        } else {
                          _selectedAssets.remove(assetPath);
                        }
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
        if (_selectedAssets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _confirmSelection,
              child: Text('选择发送 (${_selectedAssets.length})'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ),
      ],
    );
  }
}

