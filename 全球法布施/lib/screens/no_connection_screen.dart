import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/file_transfer_model.dart';
import '../services/no_connection_service.dart';
import '../services/no_connection_web_service_real.dart';
import '../widgets/no_connection_status_widget.dart';
import '../utils/network_diagnostics.dart';
import '../services/network_monitor_service_base.dart';
import '../services/network_monitor_service.dart' as monitor;

class NoConnectionScreen extends StatefulWidget {
  const NoConnectionScreen({Key? key}) : super(key: key);

  @override
  State<NoConnectionScreen> createState() => _NoConnectionScreenState();
}

class _NoConnectionScreenState extends State<NoConnectionScreen>
    with TickerProviderStateMixin {
  NoConnectionService? _noConnectionService;
  NoConnectionWebServiceReal? _noConnectionWebService;
  bool _isTransferring = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;
  String _selectedCountry = 'ALL';
  bool _isLoopMode = false;
  bool _isWebServiceInitialized = false;
  double _sendRate = 1.0; // 每秒发送MB数
  
  NetworkDiagnosticResult? _diagnosticResult;
  NetworkStats? _currentNetworkStats;
  monitor.NetworkMonitorService? _networkMonitor;
  
  late AnimationController _animationController;
  late Animation<double> _animation;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _initializeServices();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressTimer?.cancel();
    _networkMonitor?.stopMonitoring();
    _noConnectionWebService?.dispose();
    super.dispose();
  }

  /// 初始化服务
  void _initializeServices() async {
    await _initializeNoConnectionService();
    await _initializeWebService();
    await _initializeNetworkMonitor();
  }

  /// 初始化无连接服务
  Future<void> _initializeNoConnectionService() async {
    try {
      _noConnectionService = NoConnectionService(
        onProgress: (count) {
          if (mounted) {
            setState(() {
              _sentCount = count;
            });
          }
        },
        onDataSent: (dataMB) {
          if (mounted) {
            setState(() {
              _dataSentInMB = dataMB;
            });
          }
        },
        onStopped: () {
          if (mounted) {
            setState(() {
              _isTransferring = false;
            });
          }
        },
      );
      debugPrint('📱 无连接服务初始化成功');
    } catch (e) {
      debugPrint('📱 无连接服务初始化失败: $e');
    }
  }

  /// 初始化Web服务
  Future<void> _initializeWebService() async {
    try {
      _noConnectionWebService = NoConnectionWebServiceReal.instance;
      
      // 监听消息流
      _noConnectionWebService!.messageStream.listen((message) {
        if (mounted) {
          debugPrint('📊 Web端消息: $message');
        }
      });
      
      // 初始化服务
      final initialized = await _noConnectionWebService!.initialize();
      if (mounted) {
        setState(() {
          _isWebServiceInitialized = initialized;
        });
      }
      
      if (initialized) {
        debugPrint('📊 Web服务初始化成功');
      } else {
        debugPrint('📊 Web服务初始化失败');
      }
    } catch (e) {
      debugPrint('📊 Web服务初始化异常: $e');
    }
  }

  /// 初始化网络监控
  Future<void> _initializeNetworkMonitor() async {
    try {
      _networkMonitor = monitor.NetworkMonitorService();
      
      // 监听网络统计
      _networkMonitor!.networkStatsStream.listen((stats) {
        if (mounted) {
          setState(() {
            _currentNetworkStats = stats;
          });
        }
      });
      
      await _networkMonitor!.startMonitoring();
      debugPrint('📊 网络监控初始化成功');
    } catch (e) {
      debugPrint('📊 网络监控初始化失败: $e');
    }
  }

  /// 开始传输
  Future<void> _startTransfer() async {
    if (_isTransferring) return;
    
    setState(() {
      _isTransferring = true;
      _sentCount = 0;
      _dataSentInMB = 0.0;
    });
    
    _animationController.repeat();
    
    // 模拟进度更新
    _progressTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && _isTransferring) {
        setState(() {
          _sentCount++;
          _dataSentInMB += _sendRate;
        });
      }
    });
    
    debugPrint('🚀 开始传输');
  }

  /// 停止传输
  void _stopTransfer() {
    setState(() {
      _isTransferring = false;
    });
    
    _animationController.stop();
    _progressTimer?.cancel();
    
    debugPrint('⏹️ 停止传输');
  }

  /// 运行网络诊断
  Future<void> _runDiagnostics() async {
    try {
      debugPrint('🔍 开始网络诊断...');
      
      // 模拟诊断过程
      await Future.delayed(Duration(seconds: 2));
      
      setState(() {
        _diagnosticResult = NetworkDiagnosticResult(
          isConnected: true,
          latency: 50,
          bandwidth: 10.0,
          overallScore: 85,
          message: '网络状态良好，建议使用WiFi连接',
        );
      });
      
      debugPrint('✅ 网络诊断完成');
    } catch (e) {
      debugPrint('❌ 网络诊断失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('无连接传输'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeServices,
            tooltip: '重新初始化服务',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 服务状态卡片
            _buildServiceStatusCard(),
            const SizedBox(height: 16),
            
            // 网络统计卡片
            if (_currentNetworkStats != null) _buildNetworkStatsCard(),
            const SizedBox(height: 16),
            
            // 传输控制卡片
            _buildTransferControlCard(),
            const SizedBox(height: 16),
            
            // 诊断结果卡片
            if (_diagnosticResult != null) _buildDiagnosticCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '服务状态',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _isWebServiceInitialized ? Icons.check_circle : Icons.error,
                  color: _isWebServiceInitialized ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text('Web服务: ${_isWebServiceInitialized ? "已连接" : "未连接"}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _noConnectionService != null ? Icons.check_circle : Icons.error,
                  color: _noConnectionService != null ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text('无连接服务: ${_noConnectionService != null ? "已初始化" : "未初始化"}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '网络统计',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('⬆️ 上传: ${_currentNetworkStats!.uploadSpeed.toStringAsFixed(1)} KB/s'),
                Text('⬇️ 下载: ${_currentNetworkStats!.downloadSpeed.toStringAsFixed(1)} KB/s'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('总上传: ${_currentNetworkStats!.totalUploaded.toStringAsFixed(2)} MB'),
                Text('总下载: ${_currentNetworkStats!.totalDownloaded.toStringAsFixed(2)} MB'),
              ],
            ),
            const SizedBox(height: 8),
            Text('延迟: ${_currentNetworkStats!.latency}ms | 连接类型: ${_currentNetworkStats!.connectionType}'),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '传输控制',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            
            if (_isTransferring) ...[
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _animation.value,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text('已发送: $_sentCount 个文件'),
              Text('数据量: ${_dataSentInMB.toStringAsFixed(2)} MB'),
              const SizedBox(height: 12),
            ],
            
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isTransferring ? null : _startTransfer,
                  child: const Text('开始传输'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isTransferring ? _stopTransfer : null,
                  child: const Text('停止传输'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _runDiagnostics,
                  child: const Text('网络诊断'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '诊断结果',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('连接状态: ${_diagnosticResult!.isConnected ? "正常" : "异常"}'),
            Text('延迟: ${_diagnosticResult!.latency ?? "未知"}ms'),
            Text('带宽: ${_diagnosticResult!.bandwidth ?? "未知"} Mbps'),
            Text('综合评分: ${_diagnosticResult!.overallScore}/100'),
            const SizedBox(height: 8),
            Text('诊断信息:', style: Theme.of(context).textTheme.titleMedium),
            Text('• ${_diagnosticResult!.message}'),
          ],
        ),
      ),
    );
  }
}