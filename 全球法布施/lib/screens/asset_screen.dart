import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:convert' as convert;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/config/app_config.dart';
import '../services/downloaded_assets_service.dart';
import '../services/download_manager.dart';
import '../widgets/download_progress_widget.dart';

// 导入Web平台特定的包
import 'package:universal_html/html.dart' as html;

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
  List<Map<String, dynamic>> _treeAssets = [];
  Set<String> _selectedAssets = {};
  final DownloadedAssetsService _downloadedAssetsService = DownloadedAssetsService();
  final DownloadManager _downloadManager = DownloadManager();
  Map<String, String> _assetToTaskMap = {};
  StreamSubscription<DownloadTask>? _downloadSubscription;
  
  // 搜索相关
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  // 搜索防抖定时器
  Timer? _debounceTimer;
  
  // 展开状态缓存
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    print('当前平台: ${kIsWeb ? "Web" : "非Web"}');
    print('素材来源: 本地资源文件');
    _initializeDownloadedAssetsService();
    _setupDownloadListener();
    
    // 监听搜索输入变化
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // 防抖优化：300ms 内的连续输入只触发最后一次搜索
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.trim();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
          _isSearching = query.isNotEmpty;
          if (_isSearching) {
            _performSearch(query);
          } else {
            _searchResults.clear();
          }
        });
      }
    });
  }

  /// 执行搜索 - 只搜索标题
  void _performSearch(String query) {
    if (query.isEmpty) {
      _searchResults.clear();
      return;
    }
    
    final lowerQuery = query.toLowerCase();
    final results = <Map<String, dynamic>>[];
    
    for (final group in _assetGroups.values) {
      for (final asset in group) {
        final name = (asset['name'] ?? '').toString().toLowerCase();
        // 只搜索标题/文件名
        if (name.contains(lowerQuery)) {
          results.add(asset);
        }
      }
    }
    
    _searchResults = results;
  }

  void _setupDownloadListener() {
    _downloadSubscription = _downloadManager.taskStream.listen(
      (task) {
        if (mounted) {
          setState(() {
            if (task.status == DownloadStatus.downloading ||
                task.status == DownloadStatus.completed ||
                task.status == DownloadStatus.failed ||
                task.status == DownloadStatus.paused) {
              _downloadProgress[task.assetPath] = task.progress;

              if (task.status == DownloadStatus.completed) {
                _downloadingAssets.remove(task.assetPath);
                _assetToTaskMap.remove(task.assetPath);
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
                _downloadingAssets.remove(task.assetPath);
                _assetToTaskMap.remove(task.assetPath);
                _downloadProgress.remove(task.assetPath);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${task.fileName} 下载已取消'), backgroundColor: Colors.orange),
                );
              }
            }
          });
        }
      },
      onError: (error) {
        print('下载监听器错误: $error');
      },
    );
  }

  Future<void> _initializeDownloadedAssetsService() async {
    await _downloadedAssetsService.initialize();
    await _loadLocalAssets();
    await _loadLocalR2FilesList();
  }

  Future<void> _fetchTreeAssets() async {
    await _loadLocalAssets();
  }

  Future<void> _loadLocalAssets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final String manifestString = await rootBundle.loadString('assets/data/asset-manifest.json');
      final List<dynamic> files = json.decode(manifestString);

      print('从本地加载的文件数量: ${files.length}');

      final Map<String, List<Map<String, dynamic>>> groups = {};
      final List<Map<String, dynamic>> treeAssets = [];

      for (var fileInfo in files) {
        String key = fileInfo['key'];

        if (key.toLowerCase().endsWith('.json') ||
            key.contains('/.DS_Store') ||
            key.startsWith('.')) {
          continue;
        }

        if (key.contains('/')) {
          final parts = key.split('/');
          String currentPath = '';
          for (int i = 0; i < parts.length - 1; i++) {
            final dir = parts[i];
            if (i > 0) {
              currentPath += '/';
            }
            currentPath += dir;

            final fullPath = currentPath;
            final fileName = parts.sublist(i + 1).join('/');

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

  Future<void> _loadLocalR2FilesList() async {
    try {
      final String r2FilesString = await rootBundle.loadString('assets/data/r2-files-list.json');
      final Map<String, dynamic> r2Data = json.decode(r2FilesString);
      final List<dynamic> files = r2Data['objects'] ?? r2Data['files'] ?? [];

      print('从本地加载的R2文件数量: ${files.length}');

      final Map<String, List<Map<String, dynamic>>> currentGroups = Map.from(_assetGroups);

      for (var fileInfo in files) {
        String key = fileInfo['key'];

        if (key.toLowerCase().endsWith('.json') ||
            key.contains('/.DS_Store') ||
            key.startsWith('.')) {
          continue;
        }

        const String directory = 'R2素材';
        final assetInfo = {
          'name': key,
          'source': 'r2',
          'key': key,
          'directory': directory,
          'size': fileInfo['size'] ?? 0,
          'uploaded': fileInfo['uploaded'],
          'isDownloaded': false,
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
    }
  }

  Future<void> _queryR2Files() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final String baseUrl = AppConfig.isProduction
          ? AppConfig.cloudflareWorkerProdUrl
          : AppConfig.cloudflareWorkerDevUrl;
      final String url = '$baseUrl/r2?list';

      print('查询R2存储桶文件列表: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('获取R2文件列表失败: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List<dynamic> files = data['files'] ?? data['objects'] ?? [];

      print('从R2存储桶获取的文件数量: ${files.length}');

      final Map<String, List<Map<String, dynamic>>> groups = {};
      final List<Map<String, dynamic>> treeAssets = [];

      for (var fileInfo in files) {
        String key = fileInfo['key'];

        if (key.toLowerCase().endsWith('.json') ||
            key.contains('/.DS_Store') ||
            key.startsWith('.')) {
          continue;
        }

        const String directory = 'R2存储桶文件';
        final assetInfo = {
          'name': key,
          'source': 'r2',
          'key': key,
          'directory': directory,
          'description': fileInfo['key'] ?? '',
          'size': fileInfo['size'] ?? 0,
          'uploaded': fileInfo['uploaded'],
          'isDownloaded': false,
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

  Future<void> _saveFileForWeb(String fileName, List<int> bytes) async {
    if (!kIsWeb) return;

    try {
      final fileData = {
        'name': fileName,
        'size': bytes.length,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': convert.base64.encode(bytes),
      };

      final savedFilesStr = html.window.localStorage['saved_files'] ?? '[]';
      final List<dynamic> savedFiles = json.decode(savedFilesStr);

      int existingIndex = savedFiles.indexWhere((f) => f['name'] == fileName);
      if (existingIndex >= 0) {
        savedFiles[existingIndex] = fileData;
      } else {
        savedFiles.add(fileData);
      }

      html.window.localStorage['saved_files'] = json.encode(savedFiles);
      html.window.localStorage['file_$fileName'] = fileData['data'].toString();

      print('Web平台文件保存成功: $fileName, 大小: ${bytes.length} bytes');
    } catch (e) {
      print('Web平台文件保存失败: $e');
      throw Exception('Web平台文件保存失败: $e');
    }
  }

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

  List<Map<String, dynamic>> _getSavedFilesForWeb() {
    if (!kIsWeb) return [];

    try {
      final savedFilesStr = html.window.localStorage['saved_files'] ?? '[]';
      final List<dynamic> savedFiles = json.decode(savedFilesStr);

      return savedFiles
          .map((f) => {'name': f['name'], 'size': f['size'], 'timestamp': f['timestamp']})
          .toList();
    } catch (e) {
      print('获取Web平台已保存文件失败: $e');
      return [];
    }
  }

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

    final existingTaskId = _assetToTaskMap[assetPath];
    if (existingTaskId != null) {
      final task = _downloadManager.tasks[existingTaskId];
      if (task != null && task.status == DownloadStatus.paused) {
        _showDownloadDialog(existingTaskId, fileName);
        return;
      }
    }

    setState(() {
      _downloadingAssets.add(assetPath);
      _downloadProgress[assetPath] = 0.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('开始下载 $fileName')));

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
        final String baseUrl = AppConfig.isProduction
            ? AppConfig.cloudflareWorkerProdUrl
            : AppConfig.cloudflareWorkerDevUrl;
        url = '$baseUrl/r2?file=${Uri.encodeComponent(assetPath)}';
      } else {
        if (kIsWeb) {
          url = '/$assetPath';
        } else {
          final String baseUrl = AppConfig.isProduction
              ? AppConfig.cloudflareWorkerProdUrl
              : AppConfig.cloudflareWorkerDevUrl;
          url = '$baseUrl/$assetPath';
        }
      }

      print('从以下URL下载素材: $url');
      print('平台: ${kIsWeb ? "Web" : "Native"}, 来源: $source, 环境: ${AppConfig.isProduction ? "生产" : "开发"}');

      final taskId = await _downloadManager.createTask(url, fileName, assetPath);
      _assetToTaskMap[assetPath] = taskId;

      _showDownloadDialog(taskId, fileName);

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

          try {
            setState(() {
              _downloadingAssets.removeWhere((asset) => asset.contains(fileName));
              _downloadProgress.removeWhere((asset, progress) => asset.contains(fileName));
            });
            debugPrint('🧹 AssetScreen: 下载状态已清理');
          } catch (e) {
            debugPrint('❌ AssetScreen: 清理下载状态时出错: $e');
          }

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

  void _confirmSelection() {
    if (_selectedAssets.isEmpty) return;
    Navigator.pop(context, _selectedAssets.toList());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _downloadSubscription?.cancel();
    _searchController.dispose();
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
            onPressed: _isLoading ? null : _loadLocalAssets,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),
          // 内容区域
          Expanded(child: _buildBody()),
        ],
      ),
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

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索经文标题...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _isSearching = false;
                      _searchResults.clear();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _assetGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadLocalAssets, child: const Text('重试')),
          ],
        ),
      );
    }

    // 如果正在搜索，显示搜索结果
    if (_isSearching) {
      return _buildSearchResults();
    }

    return _buildAssetGroupList();
  }

  /// 构建搜索结果列表
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '未找到 "$_searchQuery" 相关的经文',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '找到 ${_searchResults.length} 个结果',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final assetInfo = _searchResults[index];
              return _buildAssetItem(assetInfo);
            },
          ),
        ),
      ],
    );
  }

  /// 构建素材分组列表 - 优化版本
  Widget _buildAssetGroupList() {
    if (_assetGroups.isEmpty) {
      return const Center(child: Text('暂无素材'));
    }

    final sortedKeys = _assetGroups.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedKeys.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('素材列表', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '选择您需要的素材，点击"选择发送"后将自动从云端服务器下载',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final dir = sortedKeys[index - 1];
        final files = _assetGroups[dir]!;
        final dirName = dir.contains('/') ? dir.split('/').last : dir;
        final isExpanded = _expandedGroups.contains(dir);

        return _OptimizedExpansionTile(
          key: ValueKey(dir),
          title: dirName,
          subtitle: dir.contains('/') ? dir : null,
          itemCount: files.length,
          isExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedGroups.add(dir);
              } else {
                _expandedGroups.remove(dir);
              }
            });
          },
          children: files,
          itemBuilder: (assetInfo) => _buildAssetItem(assetInfo),
        );
      },
    );
  }

  /// 构建单个素材项 - 优化版本
  Widget _buildAssetItem(Map<String, dynamic> assetInfo) {
    final String assetPath = assetInfo['key'];
    final String fileName = assetInfo['name'];
    final bool isSelected = _selectedAssets.contains(assetPath);
    final String? description = assetInfo['description'];
    final bool isDownloaded = _downloadedAssetsService.isAssetDownloaded(assetPath);
    final bool isDownloading = _downloadingAssets.contains(assetPath);

    // 性能优化：RepaintBoundary 隔离重绘区域
    // 当选择状态变化时，只重绘当前项，不影响其他项
    return RepaintBoundary(
      key: ValueKey('asset_$assetPath'),
      child: Column(
        children: [
          CheckboxListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDownloaded)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDownloaded)
                  const Text('已下载', style: TextStyle(color: Colors.green, fontSize: 12)),
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
          if (isDownloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _downloadProgress[assetPath] ?? 0.0,
                      minHeight: 4,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${((_downloadProgress[assetPath] ?? 0.0) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


/// 优化的展开组件 - 完全避免卡顿
class _OptimizedExpansionTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int itemCount;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final List<Map<String, dynamic>> children;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _OptimizedExpansionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.itemCount,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.children,
    required this.itemBuilder,
  });

  @override
  State<_OptimizedExpansionTile> createState() => _OptimizedExpansionTileState();
}

class _OptimizedExpansionTileState extends State<_OptimizedExpansionTile> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  @override
  void didUpdateWidget(_OptimizedExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      _isExpanded = widget.isExpanded;
    }
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    // 延迟通知父组件，避免同步setState导致卡顿
    Future.microtask(() {
      widget.onExpansionChanged(_isExpanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(Icons.expand_more),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.itemCount}',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 只在展开时构建子项，不使用动画避免卡顿
        if (_isExpanded)
          _LazyChildrenBuilder(
            children: widget.children,
            itemBuilder: widget.itemBuilder,
          ),
        const Divider(height: 1),
      ],
    );
  }
}

/// 懒加载子项构建器 - 分批构建避免卡顿
class _LazyChildrenBuilder extends StatefulWidget {
  final List<Map<String, dynamic>> children;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _LazyChildrenBuilder({
    required this.children,
    required this.itemBuilder,
  });

  @override
  State<_LazyChildrenBuilder> createState() => _LazyChildrenBuilderState();
}

class _LazyChildrenBuilderState extends State<_LazyChildrenBuilder> {
  int _loadedCount = 0;
  static const int _batchSize = 20; // 性能优化：增加批次大小

  @override
  void initState() {
    super.initState();
    // 首次加载一批
    _loadedCount = _batchSize.clamp(0, widget.children.length);
    // 如果还有更多，延迟加载
    if (_loadedCount < widget.children.length) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_loadedCount >= widget.children.length) return;
    
    // 性能优化：使用帧回调替代固定延迟，更精准地在下一帧渲染
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _loadedCount < widget.children.length) {
        setState(() {
          _loadedCount = (_loadedCount + _batchSize).clamp(0, widget.children.length);
        });
        if (_loadedCount < widget.children.length) {
          _loadMore();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _loadedCount; i++)
          widget.itemBuilder(widget.children[i]),
        if (_loadedCount < widget.children.length)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
