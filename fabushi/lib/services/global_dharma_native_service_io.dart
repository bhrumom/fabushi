import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef _LogCallbackNative = Void Function(Pointer<Utf8> jobId, Pointer<Utf8> logJson);

typedef _ExecuteFfiNative = Pointer<Utf8> Function(
  Pointer<Utf8> jobId,
  Pointer<Utf8> region,
  Uint16 port,
  Pointer<Utf8> packetJson,
  Pointer<NativeFunction<_LogCallbackNative>> callback,
);
typedef _ExecuteFfiDart = Pointer<Utf8> Function(
  Pointer<Utf8> jobId,
  Pointer<Utf8> region,
  int port,
  Pointer<Utf8> packetJson,
  Pointer<NativeFunction<_LogCallbackNative>> callback,
);

typedef _FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _FreeStringDart = void Function(Pointer<Utf8> ptr);

void _onNativeLogCallback(Pointer<Utf8> jobIdPtr, Pointer<Utf8> logJsonPtr) {
  try {
    final jobId = jobIdPtr.toDartString();
    final logJson = logJsonPtr.toDartString();
    GlobalDharmaNativeService.onLogReceived?.call(jobId, logJson);
  } catch (e) {
    debugPrint('GlobalDharmaNativeService log callback error: $e');
  }
}

class GlobalDharmaNativeService {
  static GlobalDharmaNativeService? _instance;
  static GlobalDharmaNativeService get instance => _instance ??= GlobalDharmaNativeService._();

  static void Function(String jobId, String logJson)? onLogReceived;

  DynamicLibrary? _lib;
  _ExecuteFfiDart? _executeFfi;
  _FreeStringDart? _freeStringFfi;
  bool _isInitialized = false;

  GlobalDharmaNativeService._();

  bool get isAvailable {
    if (!_isInitialized) {
      _init();
    }
    return _executeFfi != null;
  }

  void _init() {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      _lib = _loadNativeLibrary();
      if (_lib != null) {
        _executeFfi = _lib!
            .lookup<NativeFunction<_ExecuteFfiNative>>('execute_global_dharma_delivery_ffi')
            .asFunction<_ExecuteFfiDart>();
        _freeStringFfi = _lib!
            .lookup<NativeFunction<_FreeStringNative>>('free_rust_string_ffi')
            .asFunction<_FreeStringDart>();
        debugPrint('GlobalDharmaNativeService: 原生库加载成功');
      }
    } catch (e) {
      debugPrint('GlobalDharmaNativeService: 原生库加载失败 (可能需要构建): $e');
    }
  }

  DynamicLibrary? _loadNativeLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libglobal_dharma_native.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      try {
        final executablePath = Platform.resolvedExecutable;
        final macOSDir = executablePath.substring(0, executablePath.lastIndexOf('/'));
        final contentsDir = macOSDir.substring(0, macOSDir.lastIndexOf('/'));
        final libPath = '$contentsDir/Frameworks/libglobal_dharma_native.dylib';
        if (File(libPath).existsSync()) {
          return DynamicLibrary.open(libPath);
        }
      } catch (_) {}
      try {
        return DynamicLibrary.open('libglobal_dharma_native.dylib');
      } catch (_) {
        final devPath = '${Directory.current.path}/rust/target/release/libglobal_dharma_native.dylib';
        if (File(devPath).existsSync()) {
          return DynamicLibrary.open(devPath);
        }
        rethrow;
      }
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('global_dharma_native.dll');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libglobal_dharma_native.so');
    }
    return DynamicLibrary.process();
  }

  Future<Map<String, dynamic>> sendGlobalDharma({
    required String jobId,
    required String region,
    required int port,
    required Map<String, dynamic> packet,
    void Function(String logLine)? onLog,
  }) async {
    final rawJson = await sendGlobalDharmaRaw(
      jobId: jobId,
      region: region,
      port: port,
      packet: packet,
      onLog: onLog,
    );
    return jsonDecode(rawJson) as Map<String, dynamic>;
  }

  Future<String> sendGlobalDharmaRaw({
    required String jobId,
    required String region,
    required int port,
    required Map<String, dynamic> packet,
    void Function(String logLine)? onLog,
  }) async {
    if (!isAvailable || _executeFfi == null || _freeStringFfi == null) {
      throw UnsupportedError('原生发包引擎在当前环境中不可用或未初始化');
    }

    final previousCallback = onLogReceived;
    if (onLog != null) {
      onLogReceived = (rxJobId, logJson) {
        if (rxJobId == jobId) {
          onLog(logJson);
        }
      };
    }

    final jobIdPtr = jobId.toNativeUtf8();
    final regionPtr = region.toNativeUtf8();
    final packetJsonStr = jsonEncode(packet);
    final packetPtr = packetJsonStr.toNativeUtf8();
    final callbackPtr = Pointer.fromFunction<_LogCallbackNative>(_onNativeLogCallback);

    try {
      final resPtr = _executeFfi!(jobIdPtr, regionPtr, port, packetPtr, callbackPtr);
      final resultStr = resPtr.toDartString();
      _freeStringFfi!(resPtr);
      return resultStr;
    } finally {
      malloc.free(jobIdPtr);
      malloc.free(regionPtr);
      malloc.free(packetPtr);
      onLogReceived = previousCallback;
    }
  }
}
