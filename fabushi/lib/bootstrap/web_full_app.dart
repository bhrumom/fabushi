import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/design_system/app_theme.dart';
import '../features/auth/application/auth_model.dart';
import '../l10n/app_localizations.dart';
import '../models/settings_model.dart';
import '../widgets/app_wrapper.dart';

class WebFullApp extends StatelessWidget {
  const WebFullApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider(create: (_) => SettingsModel()),
      ],
      child: Consumer<SettingsModel>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConfig.appName,
            onGenerateTitle: (context) => context.l10n.appName,
            debugShowCheckedModeBanner: false,
            locale: settings.appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            localeListResolutionCallback:
                AppLocalizations.localeListResolutionCallback,
            routes: {'/login': (_) => const _WebLoginPlaceholder()},
            theme: AppTheme.webFastTheme,
            darkTheme: AppTheme.webFastTheme,
            themeMode: ThemeMode.dark,
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}

class _WebLoginPlaceholder extends StatelessWidget {
  const _WebLoginPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF09070B),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Web 登录入口已延后加载，首页优先秒开。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
