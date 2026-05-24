import 'package:flutter/foundation.dart';

enum OfflineAsrModelStatus {
  unknown,
  notInstalled,
  downloading,
  installed,
  error,
}

class OfflineAsrModelService extends ChangeNotifier {
  static OfflineAsrModelService? _instance;
  static OfflineAsrModelService get instance =>
      _instance ??= OfflineAsrModelService._();
  OfflineAsrModelService._();

  OfflineAsrModelStatus get status => OfflineAsrModelStatus.notInstalled;
  double get progress => 0;
  String get statusMessage => 'Web 暂不支持离线语音模型';

  Future<bool> refreshStatus() async => false;
  Future<String?> getInstalledModelDir() async => null;
  Future<String?> downloadModel() async => null;
  Future<void> clearModel() async {}
}
