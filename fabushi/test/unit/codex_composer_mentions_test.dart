import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/models/mini_app_model.dart';
import 'package:global_dharma_sharing/widgets/codex_desktop_chat_input.dart';

void main() {
  final registry = MiniAppRegistry(
    schemaVersion: 1,
    hostApiVersion: 'test',
    bots: const [
      MiniAppBot(
        botId: 'plugin.demo-plugin',
        title: '演示机器人',
        subtitle: '插件联系人',
        initials: '演',
        iconKey: 'apps',
        avatarColor: Color(0xFF3D8BFF),
        greeting: '',
        inputHint: '输入消息',
        miniAppId: 'demo-plugin',
        kind: MiniAppBotKind.thirdParty,
        permissions: [],
        source: MiniAppSource.marketplace,
      ),
    ],
    miniApps: const [
      MiniAppManifest(
        miniAppId: 'demo-plugin',
        botId: 'plugin.demo-plugin',
        title: '演示插件',
        subtitle: '测试插件',
        entryUrl: '',
        version: '1.0.0',
        permissions: [],
        surfaces: ['chatPanel'],
        theme: 'mcpApp',
        signature: 'test',
        reviewStatus: MiniAppReviewStatus.approved,
        source: MiniAppSource.marketplace,
        pluginPath: '/plugins/demo-plugin',
        skills: ['draft-article'],
        mcpServers: ['demo-server'],
      ),
    ],
    signature: 'test',
    updatedAt: DateTime(2026),
  );

  test('builds bot, plugin, skill, and MCP entries from one plugin', () {
    final mentions = buildCodexComposerMentions(registry);

    expect(
      mentions.map((mention) => mention.kind),
      containsAll(CodexComposerMentionKind.values),
    );
    expect(
      mentions
          .singleWhere(
            (mention) => mention.kind == CodexComposerMentionKind.bot,
          )
          .insertText,
      '@demo-plugin',
    );
    expect(
      mentions
          .singleWhere(
            (mention) => mention.kind == CodexComposerMentionKind.skill,
          )
          .insertText,
      r'$draft-article',
    );
  });

  test('manifest plugin metadata round-trips through registry JSON', () {
    final parsed = MiniAppRegistry.fromJson(registry.toJson());
    final manifest = parsed.manifestFor('demo-plugin');

    expect(manifest?.pluginPath, '/plugins/demo-plugin');
    expect(manifest?.skills, ['draft-article']);
    expect(manifest?.mcpServers, ['demo-server']);
  });

  testWidgets('@ opens the unified menu and inserts a bot contact', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final mentions = buildCodexComposerMentions(registry);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 720,
              child: CodexDesktopChatInput(
                controller: controller,
                isBusy: false,
                canSubmit: true,
                onSubmit: () {},
                mentions: mentions,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '@');
    await tester.pump();

    expect(find.text('机器人'), findsOneWidget);
    expect(find.text('插件'), findsOneWidget);
    expect(find.text('Skill'), findsOneWidget);
    expect(find.text('MCP'), findsOneWidget);

    await tester.tap(find.text('演示机器人'));
    await tester.pump();
    expect(controller.text, '@demo-plugin ');
  });
}
