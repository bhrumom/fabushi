import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

const String COUNTRY_ALL = 'ALL';
const List<String> SUPPORTED_COUNTRIES = ['CN', 'US', 'IN', 'BR', 'RU', 'NG'];

class SettingsModel extends ChangeNotifier {
  bool _darkMode = false;
  int _globalTransferFrequency = 60;
  int _wifiSignalStrength = 80;
  bool _notificationsEnabled = true;
  List<String> _selectedCountries = [];
  String _localePreference = AppLocalizations.systemLocaleCode;

  bool get darkMode => _darkMode;
  int get globalTransferFrequency => _globalTransferFrequency;
  int get wifiSignalStrength => _wifiSignalStrength;
  bool get notificationsEnabled => _notificationsEnabled;
  List<String> get selectedCountries => _selectedCountries;
  String get localePreference => _localePreference;
  Locale? get appLocale =>
      AppLocalizations.localeFromPreference(_localePreference);

  SettingsModel() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _darkMode = prefs.getBool('darkMode') ?? false;
    _globalTransferFrequency = prefs.getInt('globalTransferFrequency') ?? 60;
    _wifiSignalStrength = prefs.getInt('wifiSignalStrength') ?? 80;
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    _selectedCountries = prefs.getStringList('selectedCountries') ?? [];
    final savedLocalePreference =
        prefs.getString('localePreference') ?? AppLocalizations.systemLocaleCode;
    _localePreference =
        AppLocalizations.isSupportedPreference(savedLocalePreference)
            ? savedLocalePreference
            : AppLocalizations.systemLocaleCode;

    _selectedCountry = prefs.getString('selectedCountry') ?? COUNTRY_ALL;
    _isGlobalSendEnabled = prefs.getBool('isGlobalSendEnabled') ?? true;
    _isWifiSendEnabled = prefs.getBool('isWifiSendEnabled') ?? true;
    _isLooping = prefs.getBool('isLooping') ?? false;

    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('darkMode', _darkMode);
    await prefs.setInt('globalTransferFrequency', _globalTransferFrequency);
    await prefs.setInt('wifiSignalStrength', _wifiSignalStrength);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setStringList('selectedCountries', _selectedCountries);
    await prefs.setString('localePreference', _localePreference);
    await prefs.setString('selectedCountry', _selectedCountry);
    await prefs.setBool('isGlobalSendEnabled', _isGlobalSendEnabled);
    await prefs.setBool('isWifiSendEnabled', _isWifiSendEnabled);
    await prefs.setBool('isLooping', _isLooping);
  }

  void setDarkMode(bool value) {
    _darkMode = value;
    _saveSettings();
    notifyListeners();
  }

  void setGlobalTransferFrequency(int seconds) {
    if (seconds >= 10 && seconds <= 3600) {
      _globalTransferFrequency = seconds;
      _saveSettings();
      notifyListeners();
    }
  }

  void setWifiSignalStrength(int percentage) {
    if (percentage >= 10 && percentage <= 100) {
      _wifiSignalStrength = percentage;
      _saveSettings();
      notifyListeners();
    }
  }

  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    _saveSettings();
    notifyListeners();
  }

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

  void addCountry(String country) {
    if (!_selectedCountries.contains(country)) {
      _selectedCountries.add(country);
      _saveSettings();
      notifyListeners();
    }
  }

  void removeCountry(String country) {
    if (_selectedCountries.contains(country)) {
      _selectedCountries.remove(country);
      _saveSettings();
      notifyListeners();
    }
  }

  void setSelectedCountries(List<String> countries) {
    _selectedCountries = List.from(countries);
    _saveSettings();
    notifyListeners();
  }

  bool isValidCountry(String country) {
    return country == COUNTRY_ALL || SUPPORTED_COUNTRIES.contains(country);
  }

  void clearSelectedCountries() {
    _selectedCountries.clear();
    _saveSettings();
    notifyListeners();
  }

  void resetToDefaults() {
    _darkMode = false;
    _globalTransferFrequency = 60;
    _wifiSignalStrength = 80;
    _notificationsEnabled = true;
    _selectedCountries = [];
    _localePreference = AppLocalizations.systemLocaleCode;
    _selectedCountry = COUNTRY_ALL;
    _isGlobalSendEnabled = true;
    _isWifiSendEnabled = true;
    _isLooping = false;

    _saveSettings();
    notifyListeners();
  }

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
