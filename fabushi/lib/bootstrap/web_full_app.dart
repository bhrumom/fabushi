import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/design_system/app_theme.dart';
import '../features/auth/application/auth_model.dart';
import '../features/auth/presentation/screens/douyin_login_screen.dart'
    deferred as login;
import '../l10n/app_localizations.dart';
import '../models/file_transfer_model.dart'
    if (dart.library.html) '../models/file_transfer_model_web.dart';
import '../models/settings_model.dart';
import '../widgets/app_wrapper.dart';

class WebFullApp extends StatelessWidget {
  const WebFullApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider(create: (_) => FileTransferModel()),
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
            routes: {'/login': (_) => const _DeferredWebLoginScreen()},
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

class _DeferredWebLoginScreen extends StatefulWidget {
  const _DeferredWebLoginScreen();

  @override
  State<_DeferredWebLoginScreen> createState() =>
      _DeferredWebLoginScreenState();
}

class _DeferredWebLoginScreenState extends State<_DeferredWebLoginScreen> {
  late final Future<void> _loader = login.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loader,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return login.DouyinLoginScreen();
        }

        return const Scaffold(
          backgroundColor: Color(0xFF09070B),
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}
