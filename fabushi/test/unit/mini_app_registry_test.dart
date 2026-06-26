import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/models/mini_app_model.dart';
import 'package:global_dharma_sharing/widgets/social/social_feature_bot.dart';

void main() {
  group('Mini app registry', () {
    test('default registry includes official bots and BotFather', () {
      final registry = defaultMiniAppRegistry();

      expect(registry.schemaVersion, 1);
      expect(
        registry.bots.map((bot) => bot.botId),
        contains('bot.global-dharma'),
      );
      expect(registry.bots.map((bot) => bot.botId), contains('bot.father'));
      expect(
        registry.manifestFor('official.global-dharma')?.reviewStatus,
        MiniAppReviewStatus.trusted,
      );
    });

    test('social bot adapter preserves mini app identity', () {
      final bot = defaultMiniAppRegistry().bots.first;
      final socialBot = SocialFeatureBot.fromMiniApp(bot, index: 0);

      expect(socialBot.stableBotId, bot.botId);
      expect(socialBot.stableMiniAppId, bot.miniAppId);
      expect(socialBot.effectiveKind, bot.kind);
    });

    test('registry round-trips through json', () {
      final registry = defaultMiniAppRegistry();
      final parsed = MiniAppRegistry.fromJson(registry.toJson());

      expect(parsed.hostApiVersion, registry.hostApiVersion);
      expect(parsed.bots.length, registry.bots.length);
      expect(parsed.miniApps.length, registry.miniApps.length);
    });
  });
}
