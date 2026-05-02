import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLanguageOption {
  const AppLanguageOption({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.locale,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final Locale? locale;
}

class AppLocalizations {
  const AppLocalizations(this.localeCode);

  final String localeCode;

  static const systemLocaleCode = 'system';
  static const fallbackLocaleCode = 'en';

  static const languageOptions = <AppLanguageOption>[
    AppLanguageOption(
      code: systemLocaleCode,
      nativeName: '跟随系统',
      englishName: 'System default',
      locale: null,
    ),
    AppLanguageOption(
      code: 'zh-Hans',
      nativeName: '简体中文',
      englishName: 'Chinese (Simplified)',
      locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    ),
    AppLanguageOption(
      code: 'zh-Hant',
      nativeName: '繁體中文',
      englishName: 'Chinese (Traditional)',
      locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ),
    AppLanguageOption(
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
      locale: Locale('en'),
    ),
    AppLanguageOption(
      code: 'ja',
      nativeName: '日本語',
      englishName: 'Japanese',
      locale: Locale('ja'),
    ),
    AppLanguageOption(
      code: 'ko',
      nativeName: '한국어',
      englishName: 'Korean',
      locale: Locale('ko'),
    ),
    AppLanguageOption(
      code: 'es',
      nativeName: 'Español',
      englishName: 'Spanish',
      locale: Locale('es'),
    ),
    AppLanguageOption(
      code: 'fr',
      nativeName: 'Français',
      englishName: 'French',
      locale: Locale('fr'),
    ),
    AppLanguageOption(
      code: 'de',
      nativeName: 'Deutsch',
      englishName: 'German',
      locale: Locale('de'),
    ),
    AppLanguageOption(
      code: 'pt',
      nativeName: 'Português',
      englishName: 'Portuguese',
      locale: Locale('pt'),
    ),
    AppLanguageOption(
      code: 'ru',
      nativeName: 'Русский',
      englishName: 'Russian',
      locale: Locale('ru'),
    ),
    AppLanguageOption(
      code: 'hi',
      nativeName: 'हिन्दी',
      englishName: 'Hindi',
      locale: Locale('hi'),
    ),
  ];

  static List<Locale> get supportedLocales => languageOptions
      .where((option) => option.locale != null)
      .map((option) => option.locale!)
      .toList(growable: false);

  static const delegate = _AppLocalizationsDelegate();

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(fallbackLocaleCode);

  static Locale? localeFromPreference(String code) {
    if (code == systemLocaleCode) return null;
    for (final option in languageOptions) {
      if (option.code == code) return option.locale;
    }
    return null;
  }

  static Locale localeListResolutionCallback(
    List<Locale>? locales,
    Iterable<Locale> supportedLocales,
  ) {
    if (locales == null || locales.isEmpty) return const Locale('en');
    for (final locale in locales) {
      final resolved = resolveLocale(locale, supportedLocales);
      if (resolved != null) return resolved;
    }
    return const Locale('en');
  }

  static Locale? resolveLocale(
    Locale locale,
    Iterable<Locale> supportedLocales,
  ) {
    final canonicalCode = canonicalLocaleCode(locale);
    for (final supportedLocale in supportedLocales) {
      if (canonicalLocaleCode(supportedLocale) == canonicalCode) {
        return supportedLocale;
      }
    }
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }
    return null;
  }

  static String canonicalLocaleCode(Locale locale) {
    final languageCode = locale.languageCode.toLowerCase();
    final scriptCode = locale.scriptCode?.toLowerCase();
    final countryCode = locale.countryCode?.toLowerCase();
    if (languageCode == 'zh') {
      if (scriptCode == 'hant' ||
          countryCode == 'tw' ||
          countryCode == 'hk' ||
          countryCode == 'mo') {
        return 'zh-Hant';
      }
      return 'zh-Hans';
    }
    for (final option in languageOptions) {
      if (option.locale?.languageCode == languageCode) return option.code;
    }
    return fallbackLocaleCode;
  }

  static bool isSupportedPreference(String code) =>
      languageOptions.any((option) => option.code == code);

  static String languageNameForPreference(
    String code,
    AppLocalizations localizations,
  ) {
    if (code == systemLocaleCode) return localizations.languageSystem;
    for (final option in languageOptions) {
      if (option.code == code) return option.nativeName;
    }
    return localizations.languageSystem;
  }

  String text(String key) =>
      _localizedValues[localeCode]?[key] ??
      _localizedValues[fallbackLocaleCode]?[key] ??
      key;

  String get appName => text('appName');
  String get navHome => text('navHome');
  String get navMeditationRoom => text('navMeditationRoom');
  String get navProfile => text('navProfile');
  String get settingsLanguageTitle => text('settingsLanguageTitle');
  String get settingsLanguageSubtitle => text('settingsLanguageSubtitle');
  String get languageSystem => text('languageSystem');
  String get languageSystemDescription => text('languageSystemDescription');
  String get languageChooserTitle => text('languageChooserTitle');
  String get cancel => text('cancel');

  static const _localizedValues = <String, Map<String, String>>{
    'zh-Hans': {
      'appName': '大乘',
      'navHome': '首页',
      'navMeditationRoom': '禅室',
      'navProfile': '我的',
      'settingsLanguageTitle': '语言',
      'settingsLanguageSubtitle': '切换应用显示语言',
      'languageSystem': '跟随系统',
      'languageSystemDescription': '自动使用设备首选语言',
      'languageChooserTitle': '选择语言',
      'cancel': '取消',
    },
    'zh-Hant': {
      'appName': '大乘',
      'navHome': '首頁',
      'navMeditationRoom': '禪室',
      'navProfile': '我的',
      'settingsLanguageTitle': '語言',
      'settingsLanguageSubtitle': '切換應用程式顯示語言',
      'languageSystem': '跟隨系統',
      'languageSystemDescription': '自動使用裝置首選語言',
      'languageChooserTitle': '選擇語言',
      'cancel': '取消',
    },
    'en': {
      'appName': 'Mahayana',
      'navHome': 'Home',
      'navMeditationRoom': 'Zen Room',
      'navProfile': 'Profile',
      'settingsLanguageTitle': 'Language',
      'settingsLanguageSubtitle': 'Change the app display language',
      'languageSystem': 'System default',
      'languageSystemDescription': 'Automatically use your device language',
      'languageChooserTitle': 'Choose language',
      'cancel': 'Cancel',
    },
    'ja': {
      'appName': '大乗',
      'navHome': 'ホーム',
      'navMeditationRoom': '禅室',
      'navProfile': 'マイページ',
      'settingsLanguageTitle': '言語',
      'settingsLanguageSubtitle': 'アプリの表示言語を変更',
      'languageSystem': 'システムに合わせる',
      'languageSystemDescription': '端末の優先言語を自動的に使用',
      'languageChooserTitle': '言語を選択',
      'cancel': 'キャンセル',
    },
    'ko': {
      'appName': '대승',
      'navHome': '홈',
      'navMeditationRoom': '선실',
      'navProfile': '내 정보',
      'settingsLanguageTitle': '언어',
      'settingsLanguageSubtitle': '앱 표시 언어 변경',
      'languageSystem': '시스템 기본값',
      'languageSystemDescription': '기기 기본 언어를 자동으로 사용',
      'languageChooserTitle': '언어 선택',
      'cancel': '취소',
    },
    'es': {
      'appName': 'Mahayana',
      'navHome': 'Inicio',
      'navMeditationRoom': 'Sala Zen',
      'navProfile': 'Perfil',
      'settingsLanguageTitle': 'Idioma',
      'settingsLanguageSubtitle': 'Cambiar el idioma de la aplicación',
      'languageSystem': 'Predeterminado del sistema',
      'languageSystemDescription':
          'Usar automáticamente el idioma del dispositivo',
      'languageChooserTitle': 'Elegir idioma',
      'cancel': 'Cancelar',
    },
    'fr': {
      'appName': 'Mahayana',
      'navHome': 'Accueil',
      'navMeditationRoom': 'Salle zen',
      'navProfile': 'Profil',
      'settingsLanguageTitle': 'Langue',
      'settingsLanguageSubtitle': 'Changer la langue de l’application',
      'languageSystem': 'Langue du système',
      'languageSystemDescription':
          'Utiliser automatiquement la langue de l’appareil',
      'languageChooserTitle': 'Choisir la langue',
      'cancel': 'Annuler',
    },
    'de': {
      'appName': 'Mahayana',
      'navHome': 'Start',
      'navMeditationRoom': 'Zen-Raum',
      'navProfile': 'Profil',
      'settingsLanguageTitle': 'Sprache',
      'settingsLanguageSubtitle': 'Anzeigesprache der App ändern',
      'languageSystem': 'Systemstandard',
      'languageSystemDescription': 'Automatisch die Gerätesprache verwenden',
      'languageChooserTitle': 'Sprache wählen',
      'cancel': 'Abbrechen',
    },
    'pt': {
      'appName': 'Mahayana',
      'navHome': 'Início',
      'navMeditationRoom': 'Sala Zen',
      'navProfile': 'Perfil',
      'settingsLanguageTitle': 'Idioma',
      'settingsLanguageSubtitle': 'Alterar o idioma de exibição do app',
      'languageSystem': 'Padrão do sistema',
      'languageSystemDescription':
          'Usar automaticamente o idioma do dispositivo',
      'languageChooserTitle': 'Escolher idioma',
      'cancel': 'Cancelar',
    },
    'ru': {
      'appName': 'Махаяна',
      'navHome': 'Главная',
      'navMeditationRoom': 'Дзен-зал',
      'navProfile': 'Профиль',
      'settingsLanguageTitle': 'Язык',
      'settingsLanguageSubtitle': 'Изменить язык приложения',
      'languageSystem': 'Как в системе',
      'languageSystemDescription': 'Автоматически использовать язык устройства',
      'languageChooserTitle': 'Выберите язык',
      'cancel': 'Отмена',
    },
    'hi': {
      'appName': 'महायान',
      'navHome': 'होम',
      'navMeditationRoom': 'ज़ेन कक्ष',
      'navProfile': 'प्रोफ़ाइल',
      'settingsLanguageTitle': 'भाषा',
      'settingsLanguageSubtitle': 'ऐप की प्रदर्शन भाषा बदलें',
      'languageSystem': 'सिस्टम डिफ़ॉल्ट',
      'languageSystemDescription': 'अपने डिवाइस की भाषा अपने आप उपयोग करें',
      'languageChooserTitle': 'भाषा चुनें',
      'cancel': 'रद्द करें',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.resolveLocale(
        locale,
        AppLocalizations.supportedLocales,
      ) !=
      null;

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(
    AppLocalizations(AppLocalizations.canonicalLocaleCode(locale)),
  );

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
