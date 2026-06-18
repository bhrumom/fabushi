import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/l10n/app_localizations.dart';
import 'package:global_dharma_sharing/models/auth_model.dart';
import 'package:global_dharma_sharing/models/country_sending_model.dart';
import 'package:global_dharma_sharing/models/file_transfer_model.dart';
import 'package:global_dharma_sharing/models/leaderboard_model.dart';
import 'package:global_dharma_sharing/models/settings_model.dart';
import 'package:global_dharma_sharing/providers/tts_mute_notifier.dart';
import 'package:global_dharma_sharing/providers/video_feed_visibility_notifier.dart';
import 'package:global_dharma_sharing/screens/main_navigation_screen.dart';
import 'package:global_dharma_sharing/services/practice_stats_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class E2EAuthModel extends AuthModel {
  E2EAuthModel({User? user, String? token})
    : _currentUser = user,
      _token = token;

  User? _currentUser;
  String? _token;

  @override
  User? get currentUser => _currentUser;

  @override
  String? get authToken => _token;

  @override
  bool get isLoggedIn => _currentUser != null;

  @override
  bool get hasPremiumAccess => hasPermission('premium');

  @override
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  @override
  Future<void> refreshUserInfo() async {}

  @override
  Future<void> applyMembershipUpdate({
    required String membershipType,
    required DateTime membershipExpiry,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    _currentUser = user.copyWith(
      membershipType: membershipType,
      membershipExpiry: membershipExpiry,
    );
    notifyListeners();
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    notifyListeners();
  }

  @override
  bool hasPermission(String permission) {
    final user = _currentUser;
    if (user == null) return false;
    return switch (permission) {
      'admin' => user.isAdmin,
      'premium' => user.hasPremiumMembership || user.isAdmin,
      'basic' => true,
      _ => false,
    };
  }

  @override
  String getMembershipStatusText() {
    final user = _currentUser;
    if (user == null) return '未登录';
    if (user.isPremiumMember) return '高级会员';
    if (user.isTrialMember) return '试用会员';
    if (user.membershipType == null || user.membershipType == 'expired') {
      return '已过期';
    }
    return user.membershipType ?? '普通用户';
  }

  @override
  String? getMembershipExpiryText() {
    final expiry = _currentUser?.membershipExpiry;
    if (expiry == null) return null;
    final difference = expiry.difference(DateTime.now());
    if (difference.isNegative) return '已过期';
    if (difference.inDays > 0) return '${difference.inDays}天后到期';
    if (difference.inHours > 0) return '${difference.inHours}小时后到期';
    return '即将到期';
  }

  @override
  int? getMembershipDaysRemaining() {
    final expiry = _currentUser?.membershipExpiry;
    if (expiry == null) return null;
    return expiry.difference(DateTime.now()).inDays;
  }
}

class MacosE2EHarness {
  MacosE2EHarness(this.tester);

  final WidgetTester tester;

  static User premiumUser() {
    return User(
      username: 'mac_e2e',
      userNo: 260618,
      email: 'mac-e2e@example.test',
      nickname: '千资_E2E',
      membershipType: 'paid',
      membershipExpiry: DateTime.now().add(const Duration(days: 365)),
    );
  }

  static User expiredUser() {
    return User(
      username: 'mac_e2e_expired',
      userNo: 260619,
      email: 'mac-e2e-expired@example.test',
      nickname: '千资_E2E',
      membershipType: 'expired',
      membershipExpiry: DateTime.now().subtract(const Duration(days: 1)),
    );
  }

  Future<void> pumpApp({
    User? user,
    String? token,
    bool zhHans = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'localePreference': zhHans ? 'zh-Hans' : 'en',
      'darkMode': true,
      'notificationsEnabled': false,
      'auto_start_guide_shown': true,
      'eula_accepted': true,
    });
    PracticeStatsService().setAuthToken(null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>(
            create: (_) => E2EAuthModel(user: user, token: token),
          ),
          ChangeNotifierProvider(create: (_) => FileTransferModel()),
          ChangeNotifierProvider(create: (_) => SettingsModel()),
          ChangeNotifierProvider(create: (_) => CountrySendingModel()),
          ChangeNotifierProvider(create: (_) => LeaderboardModel()),
          ChangeNotifierProvider(create: (_) => VideoFeedVisibilityNotifier()),
          ChangeNotifierProvider(create: (_) => TtsMuteNotifier()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: zhHans
              ? const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hans',
                )
              : const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const MainNavigationScreen(),
        ),
      ),
    );
    await waitForKey('dacheng.home.title');
  }

  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await waitFor(find.text(text), timeout: timeout);
  }

  Future<void> waitForKey(
    String key, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await waitFor(find.byKey(ValueKey(key)), timeout: timeout);
  }

  Future<void> waitFor(
    Finder finder, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    fail('Timed out waiting for $finder');
  }

  Future<void> tapKey(String key) async {
    final finder = find.byKey(ValueKey(key));
    await waitFor(finder);
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapText(String text) async {
    final finder = find.text(text);
    await waitFor(finder);
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openProfile() async {
    await tapKey('dacheng.nav.profile');
    await waitForText('修行记录');
  }

  Future<void> openZenRoom() async {
    await tapKey('dacheng.nav.zen');
    await waitForKey('dacheng.zen.start_end_button');
  }

  void logStep(String message) {
    debugPrint('[macos-e2e] ${DateTime.now().toIso8601String()} $message');
  }
}
