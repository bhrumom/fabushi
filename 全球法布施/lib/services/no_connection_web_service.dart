import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Web端无连接发送服务
/// 
/// 这个服务专门为Web平台提供无连接发送功能
/// 通过JavaScript桥接器与浏览器的网络API交互
class NoConnectionWebService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;

  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;

  bool get isRunning => _isRunning;

  NoConnectionWebService({
    required this.onProgress,
    required this.onDataSent,
    required this.onStopped,
  });

  /// 初始化Web端无连接发送服务
  Future<bool> initialize() async {
    try {
      // 检查JavaScript桥接器是否可用
      if (!js.context.hasProperty('flutterNoConnectionBridge')) {
        debugPrint('❌ JavaScript桥接器未加载');
        return false;
      }

      // 初始化桥接器
      final result = js.context.callMethod('eval', [
        'window.flutterNoConnectionBridge.initialize()'
      ]);

      if (result != null && result['success'] == true) {
        debugPrint('✅ Web端无连接发送服务初始化成功');
        debugPrint('🌍 可用目标数量: ${result['targetCount']}');
        
        // 设置回调函数
        _setupCallbacks();
        
        return true;
      } else {
        debugPrint('❌ 桥接器初始化失败: ${result?['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 初始化Web端无连接发送服务失败: $e');
      return false;
    }
  }

  /// 设置JavaScript回调函数
  void _setupCallbacks() {
    try {
      // 设置进度回调
      js.context['flutterProgressCallback'] = js.allowInterop((int count) {
        _sentCount = count;
        onProgress(count);
      });

      // 设置数据发送回调
      js.context['flutterDataSentCallback'] = js.allowInterop((double dataMB) {
        _dataSentInMB = dataMB;
        onDataSent(dataMB);
      });

      // 设置停止回调
      js.context['flutterStoppedCallback'] = js.allowInterop(() {
        _isRunning = false;
        onStopped();
      });

      debugPrint('✓ JavaScript回调函数设置完成');
    } catch (e) {
      debugPrint('❌ 设置回调函数失败: $e');
    }
  }

  /// 开始无连接发送
  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
    required String country,
  }) async {
    if (_isRunning) {
      debugPrint('⚠️ 发送已在进行中');
      return;
    }

    try {
      _isRunning = true;
      _sentCount = 0;
      _dataSentInMB = 0.0;

      debugPrint('🚀 开始Web端无连接发送');
      debugPrint('📁 文件数量: ${files.length}');
      debugPrint('🌍 目标区域: $country');
      debugPrint('🔄 循环模式: $isLoop');

      // 注册文件到JavaScript
      final fileIds = <String>[];
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final fileId = 'file_${DateTime.now().millisecondsSinceEpoch}_$i';
        
        if (file.bytes != null) {
          // 大文件检查，避免内存溢出
          if (file.bytes!.length > 10 * 1024 * 1024) { // 10MB
            // 大文件只传递元数据
            final result = js.context.callMethod('eval', [
              '''
              window.flutterNoConnectionBridge.registerFile(
                "$fileId",
                "${file.name}",
                new Uint8Array(0) // 空数组
              )
              '''
            ]);
            
            if (result != null && result['success'] == true) {
              fileIds.add(fileId);
              debugPrint('✓ 大文件已注册: ${file.name} (ID: $fileId)');
            }
          } else {
            // 小文件正常处理
            final result = js.context.callMethod('eval', [
              '''
              window.flutterNoConnectionBridge.registerFile(
                "$fileId",
                "${file.name}",
                new Uint8Array([${file.bytes!.take(1000).join(',')}])
              )
              '''
            ]);
            
            if (result != null && result['success'] == true) {
              fileIds.add(fileId);
              debugPrint('✓ 小文件已注册: ${file.name} (ID: $fileId)');
            }
          }

          if (result != null && result['success'] == true) {
            fileIds.add(fileId);
            debugPrint('✓ 文件已注册: ${file.name} (ID: $fileId)');
          } else {
            debugPrint('❌ 文件注册失败: ${file.name}');
          }
        } else {
          debugPrint('⚠️ 文件 ${file.name} 没有字节数据，跳过');
        }
      }

      if (fileIds.isEmpty) {
        throw Exception('没有可发送的文件');
      }

      // 开始发送
      final sendOptions = {
        'isLoop': isLoop,
        'country': country,
      };

      final result = await _callAsyncJavaScript(
        'window.flutterNoConnectionBridge.startSending',
        [fileIds, sendOptions],
      );

      if (result != null && result['success'] == true) {
        debugPrint('✅ 无连接发送启动成功');
      } else {
        throw Exception(result?['message'] ?? '发送启动失败');
      }

    } catch (e) {
      debugPrint('❌ Web端无连接发送失败: $e');
      _isRunning = false;
      onStopped();
      rethrow;
    }
  }

  /// 停止发送
  void stopSending() {
    if (!_isRunning) return;

    try {
      final result = js.context.callMethod('eval', [
        'window.flutterNoConnectionBridge.stopSending()'
      ]);

      if (result != null && result['success'] == true) {
        debugPrint('✅ 无连接发送已停止');
      } else {
        debugPrint('⚠️ 停止发送时出现问题: ${result?['message']}');
      }
    } catch (e) {
      debugPrint('❌ 停止发送失败: $e');
    }

    _isRunning = false;
    onStopped();
  }

  /// 获取发送状态
  Map<String, dynamic>? getStatus() {
    try {
      final result = js.context.callMethod('eval', [
        'window.flutterNoConnectionBridge.getStatus()'
      ]);

      if (result != null && result['success'] == true) {
        return {
          'isRunning': result['status']['isRunning'],
          'sentCount': result['status']['sentCount'],
          'dataSentInMB': result['status']['dataSentInMB'],
          'dataSentInBytes': result['status']['dataSentInBytes'],
        };
      }
    } catch (e) {
      debugPrint('❌ 获取状态失败: $e');
    }
    return null;
  }

  /// 获取目标信息
  Map<String, dynamic>? getTargetInfo() {
    try {
      final result = js.context.callMethod('eval', [
        'window.flutterNoConnectionBridge.getTargetInfo()'
      ]);

      if (result != null && result['success'] == true) {
        return {
          'totalTargets': result['info']['totalTargets'],
          'targetsByType': result['info']['targetsByType'],
        };
      }
    } catch (e) {
      debugPrint('❌ 获取目标信息失败: $e');
    }
    return null;
  }

  /// 测试网络连接
  Future<Map<String, dynamic>?> testConnections() async {
    try {
      final result = await _callAsyncJavaScript(
        'window.flutterNoConnectionBridge.testConnections',
        [],
      );

      if (result != null && result['success'] == true) {
        debugPrint('✅ 网络连接测试完成');
        debugPrint('📊 测试结果: ${result['summary']['successful']}/${result['summary']['total']} 个目标可用');
        return {
          'results': result['results'],
          'summary': result['summary'],
        };
      } else {
        debugPrint('❌ 网络连接测试失败: ${result?['message']}');
      }
    } catch (e) {
      debugPrint('❌ 测试网络连接失败: $e');
    }
    return null;
  }

  /// 调用异步JavaScript函数
  Future<dynamic> _callAsyncJavaScript(String functionName, List<dynamic> args) async {
    final completer = Completer<dynamic>();
    
    try {
      // 创建一个唯一的回调函数名
      final callbackName = 'callback_${DateTime.now().millisecondsSinceEpoch}';
      
      // 设置回调函数
      js.context[callbackName] = js.allowInterop((result) {
        js.context.deleteProperty(callbackName);
        completer.complete(result);
      });

      // 构建JavaScript调用代码
      final argsJson = jsonEncode(args);
      final jsCode = '''
        (async function() {
          try {
            const result = await $functionName(...$argsJson);
            window.$callbackName(result);
          } catch (error) {
            window.$callbackName({
              success: false,
              message: error.message
            });
          }
        })();
      ''';

      // 执行JavaScript代码
      js.context.callMethod('eval', [jsCode]);

      // 设置超时
      Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          js.context.deleteProperty(callbackName);
          completer.completeError('JavaScript调用超时');
        }
      });

      return await completer.future;
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    }
  }

  /// 清理资源
  void dispose() {
    stopSending();
    
    // 清理JavaScript回调
    try {
      js.context.deleteProperty('flutterProgressCallback');
      js.context.deleteProperty('flutterDataSentCallback');
      js.context.deleteProperty('flutterStoppedCallback');
    } catch (e) {
      // 忽略清理错误
    }
  }
}