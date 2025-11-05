import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;
import 'package:js/js.dart';
import 'dart:convert';

@JS('navigator.bluetooth.requestDevice')
external dynamic _requestBluetoothDevice(dynamic options);

@JS()
@staticInterop
class BluetoothRemoteGATTServer {
  external factory BluetoothRemoteGATTServer();
}

@JS()
@staticInterop
class BluetoothRemoteGATTService {
  external factory BluetoothRemoteGATTService();
}

@JS()
@staticInterop
class BluetoothRemoteGATTCharacteristic {
  external factory BluetoothRemoteGATTCharacteristic();
}

@JS('window')
external dynamic get _window;

/// Web蓝牙服务
///
/// 这个服务使用Web蓝牙API在Web平台上实现与蓝牙设备的通信，
/// 可以直接发送文件数据到支持的蓝牙设备。
class WebBluetoothService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;

  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;

  dynamic _device;
  dynamic _characteristic;

  bool get isRunning => _isRunning;

  // 蓝牙服务和特征UUID
  static const String SERVICE_UUID =
      '0000180f-0000-1000-8000-00805f9b34fb'; // 示例UUID
  static const String CHARACTERISTIC_UUID =
      '00002a19-0000-1000-8000-00805f9b34fb'; // 示例UUID

  WebBluetoothService({
    required this.onProgress,
    required this.onDataSent,
    required this.onStopped,
  });

  /// 检查Web蓝牙API是否可用
  Future<bool> isAvailable() async {
    if (!kIsWeb) {
      return false;
    }

    try {
      final navigator = js_util.getProperty(_window, 'navigator');
      final bluetooth = js_util.getProperty(navigator, 'bluetooth');
      return bluetooth != null;
    } catch (e) {
      debugPrint('检查Web蓝牙API可用性时出错: $e');
      return false;
    }
  }

  /// 请求连接蓝牙设备
  Future<bool> requestDevice() async {
    if (!kIsWeb) {
      debugPrint('Web蓝牙服务仅在Web平台上可用');
      return false;
    }

    try {
      final options = {
        'filters': [
          {
            'services': [SERVICE_UUID],
          },
        ],
        'optionalServices': [SERVICE_UUID],
      };

      _device = await js_util.promiseToFuture(
        _requestBluetoothDevice(js_util.jsify(options)),
      );
      debugPrint('已连接到蓝牙设备: ${js_util.getProperty(_device, 'name')}');
      return true;
    } catch (e) {
      debugPrint('请求蓝牙设备时出错: $e');
      return false;
    }
  }

  /// 连接到GATT服务器并获取特征
  Future<bool> connectGatt() async {
    if (_device == null) {
      debugPrint('未连接蓝牙设备');
      return false;
    }

    try {
      final gattServer = await js_util.promiseToFuture(
        js_util.callMethod(_device, 'gatt.connect', []),
      );
      final service = await js_util.promiseToFuture(
        js_util.callMethod(gattServer, 'getPrimaryService', [SERVICE_UUID]),
      );
      _characteristic = await js_util.promiseToFuture(
        js_util.callMethod(service, 'getCharacteristic', [CHARACTERISTIC_UUID]),
      );

      // 设置通知监听器
      await js_util.promiseToFuture(
        js_util.callMethod(_characteristic, 'startNotifications', []),
      );

      final onCharacteristicValueChanged = js_util.allowInterop((event) {
        final value = js_util.getProperty(event, 'target.value');
        debugPrint('收到蓝牙设备响应: $value');
      });

      js_util.callMethod(_characteristic, 'addEventListener', [
        'characteristicvaluechanged',
        onCharacteristicValueChanged,
      ]);

      debugPrint('已连接到GATT服务器并获取特征');
      return true;
    } catch (e) {
      debugPrint('连接GATT服务器时出错: $e');
      return false;
    }
  }

  /// 开始发送文件
  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
  }) async {
    if (_isRunning) return;
    _isRunning = true;
    _sentCount = 0;
    _dataSentInMB = 0.0;

    try {
      // 检查蓝牙API是否可用
      final available = await isAvailable();
      if (!available) {
        debugPrint('Web蓝牙API不可用');
        _isRunning = false;
        onStopped();
        return;
      }

      // 请求连接蓝牙设备
      final deviceConnected = await requestDevice();
      if (!deviceConnected) {
        debugPrint('未能连接到蓝牙设备');
        _isRunning = false;
        onStopped();
        return;
      }

      // 连接GATT服务器
      final gattConnected = await connectGatt();
      if (!gattConnected) {
        debugPrint('未能连接到GATT服务器');
        _isRunning = false;
        onStopped();
        return;
      }

      // 开始发送文件
      do {
        for (final file in files) {
          if (!_isRunning) break;

          try {
            if (file.bytes == null) {
              debugPrint('文件 ${file.name} 没有字节数据，跳过');
              continue;
            }

            final fileBytes = file.bytes!;
            final fileName = file.name;
            final fileSize = file.size;

            debugPrint('准备通过Web蓝牙发送文件: $fileName, 大小: $fileSize 字节');

            // 发送文件元数据
            await _sendMetadata(fileName, fileSize);

            // 发送文件内容
            await _sendFileContent(fileBytes, fileName, fileSize);

            // 发送结束标记
            await _sendEndMarker(fileName);

            _sentCount++;
            onProgress(_sentCount);
          } catch (e) {
            debugPrint('通过Web蓝牙发送文件时发生错误: $e');
          }
        }
      } while (_isRunning && isLoop);
    } catch (e) {
      debugPrint('Web蓝牙发送过程中发生错误: $e');
    } finally {
      if (_isRunning) {
        _isRunning = false;
        onStopped();
      }
    }
  }

  /// 停止发送
  void stopSending() {
    _isRunning = false;
  }

  /// 发送文件元数据
  Future<void> _sendMetadata(String fileName, int fileSize) async {
    if (_characteristic == null) {
      debugPrint('未连接蓝牙特征');
      return;
    }

    final metaData = jsonEncode({
      'type': 'FILE_META',
      'name': fileName,
      'size': fileSize,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    try {
      final metaDataBytes = Uint8List.fromList(utf8.encode(metaData));
      await js_util.promiseToFuture(
        js_util.callMethod(_characteristic, 'writeValue', [metaDataBytes]),
      );
      debugPrint('已发送文件元数据: $fileName');
    } catch (e) {
      debugPrint('发送文件元数据时出错: $e');
    }

    // 短暂延迟，确保接收方准备就绪
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// 发送文件内容
  Future<void> _sendFileContent(
    Uint8List fileBytes,
    String fileName,
    int fileSize,
  ) async {
    if (_characteristic == null) {
      debugPrint('未连接蓝牙特征');
      return;
    }

    // 分块发送文件
    const chunkSize = 512; // 蓝牙MTU通常较小，使用较小的块大小
    final totalChunks = (fileBytes.length / chunkSize).ceil();
    int sentChunks = 0;

    for (var i = 0; i < fileBytes.length; i += chunkSize) {
      if (!_isRunning) break;

      final end = (i + chunkSize < fileBytes.length)
          ? i + chunkSize
          : fileBytes.length;
      final chunk = fileBytes.sublist(i, end);

      // 创建块头部
      final header = jsonEncode({
        'i': sentChunks,
        'n': fileName,
        'total': totalChunks,
      });

      // 组合头部和数据
      final headerBytes = utf8.encode(header);
      final separator = utf8.encode('|');
      final fullPacket = Uint8List(
        headerBytes.length + separator.length + chunk.length,
      );

      fullPacket.setRange(0, headerBytes.length, headerBytes);
      fullPacket.setRange(
        headerBytes.length,
        headerBytes.length + separator.length,
        separator,
      );
      fullPacket.setRange(
        headerBytes.length + separator.length,
        fullPacket.length,
        chunk,
      );

      try {
        await js_util.promiseToFuture(
          js_util.callMethod(_characteristic, 'writeValue', [fullPacket]),
        );
        sentChunks++;
        _dataSentInMB += chunk.length / (1024 * 1024);
        onDataSent(_dataSentInMB);

        if (sentChunks % 50 == 0 || sentChunks < 10) {
          final progress = (sentChunks / totalChunks * 100).toStringAsFixed(1);
          debugPrint('✓ 蓝牙块 $sentChunks/$totalChunks 发送成功 ($progress%)');
        }
      } catch (e) {
        debugPrint('发送蓝牙块 $sentChunks 时出错: $e');
        // 短暂延迟后重试
        await Future.delayed(const Duration(milliseconds: 100));
        i -= chunkSize; // 重试当前块
        continue;
      }

      // 控制发送速率，避免蓝牙堆栈过载
      await Future.delayed(const Duration(milliseconds: 50));
    }

    debugPrint('文件内容发送完成: $fileName, 共发送 $sentChunks 个块');
  }

  /// 发送结束标记
  Future<void> _sendEndMarker(String fileName) async {
    if (_characteristic == null) {
      debugPrint('未连接蓝牙特征');
      return;
    }

    final endMarker = jsonEncode({
      'type': 'FILE_END',
      'name': fileName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    try {
      final endMarkerBytes = Uint8List.fromList(utf8.encode(endMarker));
      await js_util.promiseToFuture(
        js_util.callMethod(_characteristic, 'writeValue', [endMarkerBytes]),
      );
      debugPrint('✓ 蓝牙文件结束标记发送成功');
    } catch (e) {
      debugPrint('发送结束标记时出错: $e');
    }

    // 短暂延迟，确保接收方处理完成
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
