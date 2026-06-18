import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/core/config/app_config.dart';
import 'package:integration_test/integration_test.dart';

import 'support/macos_e2e_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('macOS desktop E2E', () {
    testWidgets('home exposes local OpenClaw AI and answers in offline E2E mode', (
      tester,
    ) async {
      final app = MacosE2EHarness(tester);
      final composer = find.byKey(
        const ValueKey('dacheng.home.composer.input'),
      );
      String composerText() =>
          tester.widget<TextField>(composer).controller?.text ?? '';

      app.logStep('pump home with premium desktop user');
      await app.pumpApp(user: MacosE2EHarness.premiumUser());

      expect(find.text('大乘'), findsWidgets);
      expect(find.text('本机 OpenClaw'), findsOneWidget);
      expect(find.text('大乘能做什么'), findsOneWidget);
      expect(find.text('开始全球法布施'), findsOneWidget);
      expect(find.text('AI找资源'), findsOneWidget);
      expect(find.text('加入功课本'), findsOneWidget);
      expect(find.text('发愿文案'), findsOneWidget);

      app.logStep('verify every home quick prompt fills the composer');
      final quickPrompts = <String, String>{
        'dacheng.home.quick.what_can_do': '大乘如何帮助我做全球法布施',
        'dacheng.home.quick.global_dharma': '帮我整理一段适合全球法布施的善法文字',
        'dacheng.home.quick.ai_resources': '帮我自动查找并下载可以分享的佛法资源',
        'dacheng.home.quick.practice_book': '找一份适合放进禅室功课本的经典或仪轨',
        'dacheng.home.quick.vow_copy': '帮我写一段庄重、简洁的全球法布施发愿文',
      };
      for (final entry in quickPrompts.entries) {
        await app.tapKey(entry.key);
        expect(composerText(), contains(entry.value));
      }

      if (!AppConfig.enableE2EOfflineMode) {
        app.logStep('skip AI submit because FABUSHI_E2E_OFFLINE is false');
        return;
      }

      app.logStep('submit local OpenClaw AI prompt');
      await tester.enterText(
        composer,
        '测试本机 OpenClaw 自动化',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await app.tapKey('dacheng.home.composer.action');

      await app.waitForText('测试本机 OpenClaw 自动化');
      await app.waitForText('本机 OpenClaw E2E 响应：测试本机 OpenClaw 自动化');
    });

    testWidgets('global dharma composer exposes local loopback controls', (
      tester,
    ) async {
      final app = MacosE2EHarness(tester);
      app.logStep('pump home with premium user for local loopback access');
      await app.pumpApp(user: MacosE2EHarness.premiumUser());

      app.logStep('open composer menu and select global dharma mode');
      await app.tapKey('dacheng.home.composer.more');
      await app.tapText('全球法布施');
      await app.waitForText('法布施');
      await app.waitForText('地区 全球');

      app.logStep('open region selector and enable local loopback');
      await app.tapText('地区 全球');
      await app.waitForText('本地转经轮');
      await app.tapKey('dacheng.region.local_loopback');
      await app.tapKey('dacheng.region.apply');

      await app.waitForText('地区 全球、本地转经轮');
      expect(find.text('法布施'), findsOneWidget);
    });

    testWidgets('zen room renders practice controls and guarded start flow', (
      tester,
    ) async {
      final app = MacosE2EHarness(tester);
      app.logStep('pump app with token so start flow reaches practice guard');
      await app.pumpApp(
        user: MacosE2EHarness.premiumUser(),
        token: 'e2e-token',
      );

      await app.openZenRoom();
      expect(find.text('2D'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);
      expect(find.text('00:00'), findsWidgets);
      expect(
        find.byKey(const ValueKey('dacheng.zen.practice_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dacheng.zen.circumambulate_button')),
        findsOneWidget,
      );

      app.logStep(
        'start without selected practice opens required practice sheet',
      );
      await app.tapKey('dacheng.zen.start_end_button');
      await app.waitForText('请先选择一门深入的修行功课');
      await app.waitForText('🙏 填写主修功课');
      await app.waitForText('请先填写主修功课');

      app.logStep('type practice and verify lock confirmation dialog');
      await tester.enterText(find.byType(TextField).last, '阿弥陀佛圣号');
      await tester.pump(const Duration(milliseconds: 250));
      await app.tapText('确认锁定「阿弥陀佛圣号」');
      await app.waitForText('确认选择功课');
      await app.tapText('再想想');
    });

    testWidgets('profile, practice records, membership, and payment UI render', (
      tester,
    ) async {
      final app = MacosE2EHarness(tester);
      app.logStep(
        'pump profile with logged-in expired user and no network token',
      );
      await app.pumpApp(user: MacosE2EHarness.expiredUser());
      await app.openProfile();

      expect(find.text('千资_E2E'), findsOneWidget);
      expect(find.text('修行记录'), findsOneWidget);
      expect(find.textContaining('今日'), findsWidgets);
      expect(find.text('会员'), findsWidgets);
      expect(
        find.byKey(const ValueKey('dacheng.profile.membership_card')),
        findsOneWidget,
      );

      app.logStep('open practice record screen');
      await app.tapKey('dacheng.practice.entry_card.tap_target');
      await app.waitForText('修行记录');
      await app.waitForText('云端记录已同步');
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));

      app.logStep('open membership center and verify safe payment entrypoints');
      await app.tapKey('dacheng.profile.membership_upgrade');
      await app.waitForText('会员中心');
      await app.waitForText('选择会员套餐');
      await app.waitForText('立即购买');
      expect(find.text('月度会员'), findsOneWidget);
      expect(find.text('季度会员'), findsOneWidget);
      expect(find.text('年度会员'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dacheng.membership.buy.monthly')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dacheng.membership.buy.quarterly')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dacheng.membership.buy.yearly')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('dacheng.membership.history')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await app.waitForText('历史记录');
      await app.tapKey('dacheng.membership.tab.purchases');
      await app.waitForText('暂无购买记录');
      await app.tapKey('dacheng.membership.tab.redeems');
      await app.waitForText('暂无兑换记录');
    });
  });
}
