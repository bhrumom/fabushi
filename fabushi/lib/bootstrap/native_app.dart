import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/design_system/app_theme.dart';
import '../features/auth/application/auth_model.dart';
import '../features/auth/presentation/screens/douyin_login_screen.dart' deferred as login;
import '../l10n/app_localizations.dart';
import '../models/country_sending_model.dart';
import '../models/file_transfer_model.dart';
import '../models/leaderboard_model.dart';
import '../models/settings_model.dart';
import '../providers/tts_mute_notifier.dart';
import '../providers/video_feed_visibility_notifier.dart';
import '../widgets/app_wrapper.dart';

class NativeApp extends StatelessWidget {
  const NativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final activeTheme = kIsWeb ? AppTheme.webFastTheme : AppTheme.darkTheme;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider(create: (_) => FileTransferModel()),
        ChangeNotifierProvider(create: (_) => SettingsModel()),
        ChangeNotifierProvider(create: (_) => CountrySendingModel()),
        ChangeNotifierProvider(create: (_) => LeaderboardModel()),
        ChangeNotifierProvider(create: (_) => VideoFeedVisibilityNotifier()),
        ChangeNotifierProvider(create: (_) {
          final notifier = TtsMuteNotifier();
          unawaited(notifier.initialize());
          return notifier;
        }),
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
            onGenerateRoute: (routeSettings) {
              if (routeSettings.name == '/login') {
                return MaterialPageRoute<void>(
                  settings: routeSettings,
                  builder: (_) => const _DeferredLoginScreen(),
                );
              }
              return null;
            },
            theme: activeTheme,
            darkTheme: activeTheme,
            themeMode: ThemeMode.dark,
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}

class _DeferredLoginScreen extends StatefulWidget {
  const _DeferredLoginScreen();

  @override
  State<_DeferredLoginScreen> createState() => _DeferredLoginScreenState();
}

class _DeferredLoginScreenState extends State<_DeferredLoginScreen> {
  late final Future<void> _loader = login.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loader,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const login.DouyinLoginScreen();
        }

        return const Scaffold(
          backgroundColor: Color(0xFF09070B),
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}
