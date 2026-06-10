import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/design_system/app_theme.dart';
import '../features/auth/application/auth_model.dart';
import '../features/auth/presentation/screens/douyin_login_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/country_sending_model.dart';
import '../models/file_transfer_model.dart';
import '../models/leaderboard_model.dart';
import '../models/settings_model.dart';
import '../providers/tts_mute_notifier.dart';
import '../providers/video_feed_visibility_notifier.dart';
import '../widgets/app_wrapper.dart';

Future<void> bootstrapApplication() async {
  throw UnsupportedError('Use a platform bootstrap implementation.');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
            routes: {'/login': (_) => const DouyinLoginScreen()},
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}
