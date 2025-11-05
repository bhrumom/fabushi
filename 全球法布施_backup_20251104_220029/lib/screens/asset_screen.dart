import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:convert' as convert;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/unified_config.dart';
import '../services/downloaded_assets_service.dart';
import '../services/download_manager.dart';
import '../widgets/download_progress_widget.dart';

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
  final DownloadManager _downloadManager = DownloadManager();
  Map<String, String> _assetToTaskMap = {}; // assetPath到taskId的映射
  StreamSubscription<DownloadTask>? _downloadSubscription; // 下载监听器订阅


  @override
  void initState() {
    super.initState();
    print('当前平台: ${kIsWeb ? "Web" : "非Web"}');
    print('素材来源: 本地资源文件');
    
    // 初始化已下载素材服务
    _initializeDownloadedAssetsService();
    
    // 监听下载任务更新
    _setupDownloadListener();
  }

  /// 设置下载监听器
  void _setupDownloadListener() {
    _downloadSubscription = _downloadManager.taskStream.listen((task) {
      if (mounted) {
        setState(() {
          // 更新下载进度
          if (task.status == DownloadStatus.downloading || 
              task.status == DownloadStatus.completed || 
              task.status == DownloadStatus.failed ||
              task.status == DownloadStatus.paused) {
            _downloadProgress[task.assetPath] = task.progress;
            
            if (task.status == DownloadStatus.completed) {
              _downloadingAssets.remove(task.assetPath);
              _assetToTaskMap.remove(task.assetPath);
              
              // 标记为已下载
              _downloadedAssetsService.markAssetAsDownloaded(task.assetPath);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${task.fileName} 下载完成！')),
              );
            } else if (task.status == DownloadStatus.failed) {
              _downloadingAssets.remove(task.assetPath);
              _assetToTaskMap.remove(task.assetPath);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${task.fileName} 下载失败: ${task.error}'),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (task.status == DownloadStatus.paused && task.error == '下载已取消') {
              // 处理取消状态
              _downloadingAssets.remove(task.assetPath);
              _assetToTaskMap.remove(task.assetPath);
              _downloadProgress.remove(task.assetPath);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${task.fileName} 下载已取消'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        });
      }
    }, onError: (error) {
      print('下载监听器错误: $error');
    });
  }

  /// 初始化已下载素材服务
  Future<void> _initializeDownloadedAssetsService() async {
    await _downloadedAssetsService.initialize();
    // 所有平台都从本地加载素材列表
    await _loadLocalAssets();
    // 加载本地R2文件列表，无需查询即可查看
    await _loadLocalR2FilesList();
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

  // 加载本地R2文件列表并合并到普通素材中
  Future<void> _loadLocalR2FilesList() async {
    try {
      // 从本地资源文件加载R2文件列表
      final String r2FilesString = await rootBundle.loadString('assets/data/r2-files-list.json');
      final Map<String, dynamic> r2Data = json.decode(r2FilesString);
      
      // 获取文件列表（兼容objects和files字段）
      final List<dynamic> files = r2Data['objects'] ?? r2Data['files'] ?? [];
      
      print('从本地加载的R2文件数量: ${files.length}');
      
      // 将R2文件合并到普通素材分组中
      final Map<String, List<Map<String, dynamic>>> currentGroups = Map.from(_assetGroups);
      
      for (var fileInfo in files) {
        String key = fileInfo['key'];
        
        // 过滤掉JSON文件和隐藏文件（如.DS_Store）
        if (key.toLowerCase().endsWith('.json') || key.contains('/.DS_Store') || key.startsWith('.')) {
          continue;
        }
        
        // R2文件统一放入"R2素材"分组
        const String directory = 'R2素材';
        final assetInfo = {
          'name': key, // 文件名就是key
          'source': 'r2', // R2存储桶中的文件
          'key': key,
          'directory': directory,
          'size': fileInfo['size'] ?? 0,
          'uploaded': fileInfo['uploaded'], // R2特有的上传时间
          'isDownloaded': false, // 标记是否已下载
        };
        
        if (!currentGroups.containsKey(directory)) {
          currentGroups[directory] = [];
        }
        
        currentGroups[directory]!.add(assetInfo);
      }

      print('R2文件已合并到普通素材，当前分组数量: ${currentGroups.length}');

      setState(() {
        _assetGroups = currentGroups;
      });
      
      print('本地R2文件列表已合并完成');
    } catch (e) {
      print('加载本地R2文件列表失败: $e');
      // 如果加载失败，不影响主功能
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
        _assetGroups.addAll(groups);
        _treeAssets.addAll(treeAssets);
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

  /// 下载素材（增强版，支持进度显示、暂停、断点续传）
  Future<void> _downloadAsset(Map<String, dynamic> assetInfo) async {
    final String assetPath = assetInfo['key'];
    final String fileName = assetInfo['name'];
    final String source = assetInfo['source'];

    if (_downloadingAssets.contains(assetPath)) return;

    // 检查是否已有下载任务
    final existingTaskId = _assetToTaskMap[assetPath];
    if (existingTaskId != null) {
      final task = _downloadManager.tasks[existingTaskId];
      if (task != null && task.status == DownloadStatus.paused) {
        // 如果任务已暂停，显示恢复对话框
        _showDownloadDialog(existingTaskId, fileName);
        return;
      }
    }

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
        // R2文件通过Cloudflare Worker下载
        final String baseUrl = UnifiedConfig.isProduction ? UnifiedConfig.cloudflareWorkerProdUrl : UnifiedConfig.cloudflareWorkerDevUrl;
        url = '$baseUrl/r2?file=${Uri.encodeComponent(assetPath)}';
      } else {
        // 静态文件下载策略
        if (kIsWeb) {
          // Web平台：使用相对路径，避免CORS问题
          url = '/$assetPath';
        } else {
          // 非Web平台：使用Cloudflare Worker的完整URL访问静态文件
          // 因为静态文件部署在Web平台上，需要通过Worker代理访问
          final String baseUrl = UnifiedConfig.isProduction ? UnifiedConfig.cloudflareWorkerProdUrl : UnifiedConfig.cloudflareWorkerDevUrl;
          url = '$baseUrl/$assetPath';
        }
      }
      
      print('从以下URL下载素材: $url');
      print('平台: ${kIsWeb ? "Web" : "Native"}, 来源: $source, 环境: ${UnifiedConfig.isProduction ? "生产" : "开发"}');

      // 创建下载任务
      final taskId = await _downloadManager.createTask(url, fileName, assetPath);
      _assetToTaskMap[assetPath] = taskId;

      // 显示下载进度对话框
      _showDownloadDialog(taskId, fileName);

      // 开始下载
      await _downloadManager.startDownload(taskId);

    } catch (e) {
      setState(() {
        _downloadingAssets.remove(assetPath);
        _downloadProgress.remove(assetPath);
        _assetToTaskMap.remove(assetPath);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载 $fileName 失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 显示下载进度对话框
  void _showDownloadDialog(String taskId, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadProgressDialog(
        taskId: taskId,
        downloadManager: _downloadManager,
        onComplete: () {
          debugPrint('🎉 AssetScreen: 下载完成回调触发');
          
          try {
            // 下载完成后的处理
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$fileName 下载完成！'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
              debugPrint('✅ AssetScreen: 下载完成提示已显示');
            }
          } catch (e) {
            debugPrint('❌ AssetScreen: 显示下载完成提示时出错: $e');
          }
          
          // 清理下载状态
          try {
            setState(() {
              _downloadingAssets.removeWhere((asset) => asset.contains(fileName));
              _downloadProgress.removeWhere((asset, progress) => asset.contains(fileName));
            });
            debugPrint('🧹 AssetScreen: 下载状态已清理');
          } catch (e) {
            debugPrint('❌ AssetScreen: 清理下载状态时出错: $e');
          }
          
          // 确保关闭对话框 - 与Web平台保持一致
          try {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              debugPrint('🔒 AssetScreen: 下载进度对话框已关闭');
            }
          } catch (e) {
            debugPrint('⚠️ AssetScreen: 关闭对话框时出错: $e');
          }
        },
      ),
    );
  }

  // 确认选择素材并返回
  void _confirmSelection() {
    if (_selectedAssets.isEmpty) return;
    
    // 将选中的素材信息传递回上一个页面
    Navigator.pop(context, _selectedAssets.toList());
  }

  @override
  void dispose() {
    // 取消下载监听器订阅
    _downloadSubscription?.cancel();
    // 注意：下载管理器是单例，不应在这里释放，避免影响正在进行的下载任务
    // _downloadManager.dispose(); // 移除这行，避免提前释放
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('素材列表'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : () {
              _loadLocalAssets();
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _selectedAssets.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _confirmSelection,
              icon: Icon(Icons.send),
              label: Text('选择发送 (${_selectedAssets.length})'),
              backgroundColor: Theme.of(context).primaryColor,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null && _assetGroups.isEmpty) {
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 素材列表（包含普通素材和R2素材）
          if (_assetGroups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '素材列表',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '选择您需要的素材，点击"选择发送"后将自动从云端服务器下载',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            Divider(),
            _buildAssetList(_assetGroups),
          ],
        ],
      ),
    );
  }

  /// 构建素材列表的通用方法
  Widget _buildAssetList(Map<String, List<Map<String, dynamic>>> assetGroups) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(), // 禁用内部滚动，由外部ListView控制
      itemCount: assetGroups.keys.length,
      itemBuilder: (context, index) {
        final dir = assetGroups.keys.elementAt(index);
        final files = assetGroups[dir]!;
        
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

            return Column(
              children: [
                CheckboxListTile(
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
                ),
                // 显示下载进度
                if (_downloadingAssets.contains(assetPath))
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: _downloadProgress[assetPath] ?? 0.0,
                            minHeight: 4,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${((_downloadProgress[assetPath] ?? 0.0) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

