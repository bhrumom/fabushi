import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

// 国家常量定义
const String COUNTRY_ALL = 'ALL';
const List<String> SUPPORTED_COUNTRIES = [
  'CN', // 中国
  'US', // 美国
  'IN', // 印度
  'BR', // 巴西
  'RU', // 俄罗斯
  'NG', // 尼日利亚
];

class SettingsModel extends ChangeNotifier {
  // 默认设置
  bool _darkMode = false;
  int _globalTransferFrequency = 60; // 全球传输频率（秒）
  int _wifiSignalStrength = 80; // WiFi信号强度（百分比）
  bool _notificationsEnabled = true;
  List<String> _selectedCountries = []; // 选中的国家列表
  String _localePreference = AppLocalizations.systemLocaleCode; // 应用显示语言

  // 获取深色模式状态
  bool get darkMode => _darkMode;

  // 获取全球传输频率
  int get globalTransferFrequency => _globalTransferFrequency;

  // 获取WiFi信号强度
  int get wifiSignalStrength => _wifiSignalStrength;

  // 获取通知状态
  bool get notificationsEnabled => _notificationsEnabled;

  // 获取选中的国家列表
  List<String> get selectedCountries => _selectedCountries;

  // 获取应用语言偏好，system 表示跟随系统
  String get localePreference => _localePreference;

  // 获取 MaterialApp 可直接使用的 Locale；null 表示跟随系统
  Locale? get appLocale =>
      AppLocalizations.localeFromPreference(_localePreference);

  // 构造函数
  SettingsModel() {
    _loadSettings();
  }

  // 从本地存储加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _darkMode = prefs.getBool('darkMode') ?? false;
    _globalTransferFrequency = prefs.getInt('globalTransferFrequency') ?? 60;
    _wifiSignalStrength = prefs.getInt('wifiSignalStrength') ?? 80;
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    _selectedCountries = prefs.getStringList('selectedCountries') ?? [];
    final savedLocalePreference =
        prefs.getString('localePreference') ?? AppLocalizations.systemLocaleCode;
    _localePreference = AppLocalizations.isSupportedPreference(
      savedLocalePreference,
    )
        ? savedLocalePreference
        : AppLocalizations.systemLocaleCode;

    // 加载国家发送配置
    _selectedCountry = prefs.getString('selectedCountry') ?? COUNTRY_ALL;
    _isGlobalSendEnabled = prefs.getBool('isGlobalSendEnabled') ?? true;
    _isWifiSendEnabled = prefs.getBool('isWifiSendEnabled') ?? true;
    _isLooping = prefs.getBool('isLooping') ?? false;

    notifyListeners();
  }

  // 保存设置到本地存储
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('darkMode', _darkMode);
    await prefs.setInt('globalTransferFrequency', _globalTransferFrequency);
    await prefs.setInt('wifiSignalStrength', _wifiSignalStrength);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setStringList('selectedCountries', _selectedCountries);
    await prefs.setString('localePreference', _localePreference);

    // 保存国家发送配置
    await prefs.setString('selectedCountry', _selectedCountry);
    await prefs.setBool('isGlobalSendEnabled', _isGlobalSendEnabled);
    await prefs.setBool('isWifiSendEnabled', _isWifiSendEnabled);
    await prefs.setBool('isLooping', _isLooping);
  }

  // 设置深色模式
  void setDarkMode(bool value) {
    _darkMode = value;
    _saveSettings();
    notifyListeners();
  }

  // 设置全球传输频率
  void setGlobalTransferFrequency(int seconds) {
    if (seconds >= 10 && seconds <= 3600) {
      _globalTransferFrequency = seconds;
      _saveSettings();
      notifyListeners();
    }
  }

  // 设置WiFi信号强度
  void setWifiSignalStrength(int percentage) {
    if (percentage >= 10 && percentage <= 100) {
      _wifiSignalStrength = percentage;
      _saveSettings();
      notifyListeners();
    }
  }

  // 设置通知状态
  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  // 设置应用显示语言。传入 system 时跟随系统语言。
  Future<void> setLocalePreference(String value) async {
    final nextValue = AppLocalizations.isSupportedPreference(value)
        ? value
        : AppLocalizations.systemLocaleCode;
    if (_localePreference == nextValue) {
      return;
    }
    _localePreference = nextValue;
    await _saveSettings();
    notifyListeners();
  }

  // 添加国家到选中列表
  void addCountry(String country) {
    if (!_selectedCountries.contains(country)) {
      _selectedCountries.add(country);
      _saveSettings();
      notifyListeners();
    }
  }

  // 从选中列表移除国家
  void removeCountry(String country) {
    if (_selectedCountries.contains(country)) {
      _selectedCountries.remove(country);
      _saveSettings();
      notifyListeners();
    }
  }

  // 设置选中的国家列表
  void setSelectedCountries(List<String> countries) {
    _selectedCountries = List.from(countries);
    _saveSettings();
    notifyListeners();
  }

  // 验证国家代码是否有效
  bool isValidCountry(String country) {
    return country == COUNTRY_ALL || SUPPORTED_COUNTRIES.contains(country);
  }

  // 清空选中的国家列表
  void clearSelectedCountries() {
    _selectedCountries.clear();
    _saveSettings();
    notifyListeners();
  }

  // 重置所有设置为默认值
  void resetToDefaults() {
    _darkMode = false;
    _globalTransferFrequency = 60;
    _wifiSignalStrength = 80;
    _notificationsEnabled = true;
    _selectedCountries = [];
    _localePreference = AppLocalizations.systemLocaleCode;

    // 重置国家相关设置
    _selectedCountry = COUNTRY_ALL;
    _isGlobalSendEnabled = true;
    _isWifiSendEnabled = true;
    _isLooping = false;

    _saveSettings();
    notifyListeners();
  }

  // 国家相关设置
  String _selectedCountry = 'ALL';
  bool _isGlobalSendEnabled = true;
  bool _isWifiSendEnabled = true;
  bool _isLooping = false;

  String get selectedCountry => _selectedCountry;
  bool get isGlobalSendEnabled => _isGlobalSendEnabled;
  bool get isWifiSendEnabled => _isWifiSendEnabled;
  bool get isLooping => _isLooping;

  void setSelectedCountry(String country) {
    if (_selectedCountry != country) {
      _selectedCountry = country;
      notifyListeners();
    }
  }

  void setGlobalSendEnabled(bool value) {
    if (_isGlobalSendEnabled != value) {
      _isGlobalSendEnabled = value;
      notifyListeners();
    }
  }

  void setWifiSendEnabled(bool value) {
    if (_isWifiSendEnabled != value) {
      _isWifiSendEnabled = value;
      notifyListeners();
    }
  }

  void setLooping(bool value) {
    if (_isLooping != value) {
      _isLooping = value;
      notifyListeners();
    }
  }

  // 调试信息
  void debugInfo() {
    if (kDebugMode) {
      print('Settings: {');
      print('  localePreference: $localePreference,');
      print('  selectedCountry: $selectedCountry,');
      print('  isGlobalSendEnabled: $isGlobalSendEnabled,');
      print('  isWifiSendEnabled: $isWifiSendEnabled,');
      print('  isLooping: $isLooping');
      print('}');
    }
  }
}
