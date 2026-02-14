import 'package:shared_preferences/shared_preferences.dart';

/// EULA/用户协议同意状态管理服务
class EulaService {
  static const String _eulaAcceptedKey = 'eula_accepted';
  static const String _eulaAcceptedVersionKey = 'eula_accepted_version';
  static const String currentVersion = '1.0';

  /// 检查用户是否已接受 EULA
  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_eulaAcceptedKey) ?? false;
    final version = prefs.getString(_eulaAcceptedVersionKey) ?? '';
    return accepted && version == currentVersion;
  }

  /// 记录用户接受 EULA
  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eulaAcceptedKey, true);
    await prefs.setString(_eulaAcceptedVersionKey, currentVersion);
  }

  /// 获取 EULA 全文
  static String getEulaText() {
    return '''
《大乘 用户协议与服务条款》

最后更新日期：2026年2月11日

欢迎使用"大乘"应用（以下简称"本应用"）。在使用本应用之前，请您仔细阅读以下条款。使用本应用即表示您同意遵守本协议的所有条款。

一、服务说明
本应用为用户提供佛教经文阅读、朗诵、分享及社区交流等服务。

二、用户行为规范
用户在使用本应用时，必须遵守以下规范：
1. 不得发布、传播任何违法、有害、威胁、辱骂、骚扰、诽谤、粗俗、淫秽或其他令人反感的内容。
2. 不得发布与佛教文化和本应用宗旨不相关的广告或商业推广信息。
3. 不得冒充他人或虚假陈述与任何人或实体的关系。
4. 不得利用本应用进行任何违反法律法规的活动。
5. 尊重其他用户，保持友善、和谐的社区氛围。

三、不当内容零容忍政策
本应用对不当内容和滥用行为实行零容忍政策：
1. 任何不当内容（包括但不限于色情、暴力、仇恨言论、骚扰等）一经发现或举报，将在24小时内予以删除。
2. 发布不当内容的用户账号将被立即封禁，不予恢复。
3. 涉嫌违法犯罪的内容将依法向有关部门报告。

四、内容审核与举报
1. 本应用设有内容过滤和审核机制，自动检测并阻止不当内容的发布。
2. 用户可通过应用内的"举报"功能对不当内容或滥用行为进行举报。
3. 我们将在收到举报后24小时内进行审核和处理。
4. 用户可以屏蔽其他用户，被屏蔽用户的内容将从您的信息流中移除。

五、隐私保护
1. 我们重视用户隐私，仅收集提供服务所必需的信息。
2. 用户个人信息不会在未经授权的情况下出售或分享给第三方。
3. 详细隐私政策请参阅本应用的隐私政策页面。

六、知识产权
1. 本应用中的佛教经文属于公共领域，可自由传播。
2. 用户上传的原创内容，版权归用户所有。
3. 用户授予本应用非独占、免版税的许可，用于在应用内展示和分发其内容。

七、免责声明
1. 本应用提供的佛教经文和内容仅供参考学习，不构成宗教指导建议。
2. 对于用户生成内容的准确性和合法性，本应用不承担责任。
3. 因不可抗力导致的服务中断，本应用不承担责任。

八、协议修改
我们保留随时修改本协议的权利。修改后的协议将在应用内公布，继续使用本应用即视为接受修改后的协议。

九、联系方式
如有任何问题或建议，请通过以下方式联系我们：
邮箱：support@ombhrum.com

感谢您使用"大乘"应用，祝您修行精进、法喜充满！
''';
  }

  /// 获取隐私政策全文
  static String getPrivacyPolicyText() {
    return '''
《大乘 隐私政策》

最后更新日期：2026年2月11日

一、信息收集
我们可能收集以下信息：
- 账户信息：用户名、邮箱地址
- 使用数据：应用使用统计、阅读记录
- 设备信息：设备型号、操作系统版本

二、信息使用
收集的信息用于：
- 提供和改善应用服务
- 个性化用户体验
- 发送服务相关通知

三、信息保护
我们采取合理的安全措施保护用户信息，防止未经授权的访问、使用或泄露。

四、联系我们
如有隐私相关问题，请联系：support@ombhrum.com

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ENGLISH VERSION

"Mahayana" End User License Agreement (EULA)

Last Updated: February 11, 2026

Welcome to "Mahayana" (the "App"). Please read these terms carefully before using the App. By using the App, you agree to be bound by all terms of this agreement.

1. Service Description
The App provides Buddhist scripture reading, recitation, sharing, and community interaction services.

2. User Conduct
Users must comply with the following rules:
- Do not post, transmit, or share any unlawful, harmful, threatening, abusive, harassing, defamatory, vulgar, obscene, or otherwise objectionable content.
- Do not post advertisements or commercial promotions unrelated to the App's purpose.
- Do not impersonate any person or entity.
- Do not use the App for any illegal activities.
- Respect other users and maintain a friendly, harmonious community atmosphere.

3. Zero Tolerance Policy for Objectionable Content
This App enforces a ZERO TOLERANCE policy for objectionable content and abusive behavior:
- Any objectionable content (including but not limited to pornography, violence, hate speech, harassment, etc.) will be REMOVED WITHIN 24 HOURS upon discovery or report.
- User accounts that post objectionable content will be PERMANENTLY BANNED without restoration.
- Content suspected of criminal activity will be reported to relevant authorities.

4. Content Moderation and Reporting
- The App employs content filtering and moderation mechanisms to automatically detect and block objectionable content.
- Users can report objectionable content or abusive behavior using the in-app "Report" feature.
- All reports will be reviewed and acted upon within 24 hours.
- Users can block other users, and blocked users' content will be removed from their feed.

5. Privacy
- We value user privacy and only collect information necessary for providing services.
- Personal information will not be sold or shared with third parties without authorization.

6. Contact
For any questions: support@ombhrum.com
''';
  }
}
