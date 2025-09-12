import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../services/p2p_network_service.dart';
import '../widgets/transfer_stats_display.dart';
import '../widgets/transfer_control_panel.dart';
import '../widgets/transfer_status_info.dart';

/// P2P网络演示屏幕
/// 
/// 这个屏幕展示了P2P网络的功能，允许用户测试无中继服务器的文件传输。
class P2PDemoScreen extends StatefulWidget {
  const P2PDemoScreen({Key? key}) : super(key: key);

  @override
  _P2PDemoScreenState createState() => _P2PDemoScreenState();
}

class _P2PDemoScreenState extends State<P2PDemoScreen> {
  late final _p2pService = P2PNetworkService.getInstance();
  
  bool _isInitialized = false;
  bool _isInitializing = false;
  int _connectedPeers = 0;
  List<String> _connectedPeerIds = [];
  List<PlatformFile> _selectedFiles = [];
  
  bool _isSending = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;
  
  StreamSubscription? _connectionSubscription;
  
  @override
  void initState() {
    super.initState();
    _initializeP2PNetwork();
  }
  
  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }
  
  /// 初始化P2P网络
  Future<void> _initializeP2PNetwork() async {
    if (_isInitializing || _isInitialized) return;
    
    setState(() {
      _isInitializing = true;
    });
    
    try {
      final success = await _p2pService.initialize();
      
      if (success) {
        _connectionSubscription = _p2pService.onConnectionChanged.listen((count) {
          setState(() {
            _connectedPeers = count;
            _connectedPeerIds = _p2pService.connectedPeerIds;
          });
        });
        
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
          _connectedPeers = _p2pService.connectedPeersCount;
          _connectedPeerIds = _p2pService.connectedPeerIds;
        });
      } else {
        setState(() {
          _isInitialized = false;
          _isInitializing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('初始化P2P网络失败'))
        );
      }
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _isInitializing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('初始化P2P网络时出错: $e'))
      );
    }
  }
  
  /// 选择文件
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件时出错: $e'))
      );
    }
  }
  
  /// 广播文件
  Future<void> _broadcastFiles() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择文件'))
      );
      return;
    }
    
    if (_connectedPeers == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有连接的节点'))
      );
      return;
    }
    
    setState(() {
      _isSending = true;
      _sentCount = 0;
      _dataSentInMB = 0.0;
    });
    
    try {
      for (final file in _selectedFiles) {
        final result = await _p2pService.broadcastFile(file);
        
        if (result['success']) {
          setState(() {
            _sentCount += result['sentCount'] as int;
            _dataSentInMB += result['dataSentInMB'] as double;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件广播成功: ${file.name}, 已发送到 ${result['sentCount']} 个节点'))
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件广播失败: ${result['message']}'))
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('广播文件时出错: $e'))
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }
  
  /// 打开演示页面
  void _openDemoPage() {
    // 移除直接的HTML调用，使用平台安全的方式
    debugPrint('尝试打开P2P演示页面');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P网络演示'),
        actions: [
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: '在新窗口打开演示',
              onPressed: _openDemoPage,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'P2P网络状态',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    _buildStatusRow('初始化状态:', _isInitialized ? '已初始化' : (_isInitializing ? '初始化中...' : '未初始化')),
                    _buildStatusRow('已连接节点数:', '$_connectedPeers'),
                    _buildStatusRow('WebRTC支持:', _p2pService.isWebRTCSupported ? '支持' : '不支持'),
                    if (_connectedPeerIds.isNotEmpty)
                      _buildStatusRow('已连接节点:', ''),
                    if (_connectedPeerIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _connectedPeerIds
                              .map((peerId) => Text(peerId, style: const TextStyle(fontFamily: 'monospace')))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16.0),
            
            // 文件选择卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '文件选择',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.file_upload),
                          label: const Text('选择文件'),
                          onPressed: _pickFiles,
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Text(
                            _selectedFiles.isEmpty
                                ? '未选择文件'
                                : '已选择 ${_selectedFiles.length} 个文件',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedFiles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _selectedFiles
                              .map((file) => Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '${file.name} (${_formatFileSize(file.size)})',
                                      style: const TextStyle(fontSize: 12.0),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16.0),
            
            // 传输控制卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '传输控制',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('广播文件'),
                      onPressed: _selectedFiles.isEmpty || _connectedPeers == 0 || _isSending
                          ? null
                          : _broadcastFiles,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48.0),
                      ),
                    ),
                    if (_isSending)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: const LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16.0),
            
            // 传输统计卡片
            if (_sentCount > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '传输统计',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16.0),
                      _buildStatusRow('已发送节点数:', '$_sentCount'),
                      _buildStatusRow('已发送数据:', '${_dataSentInMB.toStringAsFixed(2)} MB'),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16.0),
            
            // 说明卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '使用说明',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      '1. 本演示展示了无中继服务器的P2P文件传输功能。\n'
                      '2. 要测试P2P传输，请在不同的浏览器标签页或设备上打开此应用。\n'
                      '3. 节点之间会自动发现并建立连接。\n'
                      '4. 选择文件并点击"广播文件"按钮，文件将直接发送到所有连接的节点。\n'
                      '5. 点击右上角的图标可以在新窗口打开更详细的演示页面。',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建状态行
  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8.0),
          Text(value),
        ],
      ),
    );
  }
  
  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}