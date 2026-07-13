import 'package:flutter/material.dart';

import '../services/telegram/telegram_chat_session.dart';

class TelegramAuthorizationScreen extends StatefulWidget {
  const TelegramAuthorizationScreen({super.key});

  @override
  State<TelegramAuthorizationScreen> createState() =>
      _TelegramAuthorizationScreenState();
}

class _TelegramAuthorizationScreenState
    extends State<TelegramAuthorizationScreen> {
  final TelegramChatSession _session = TelegramChatSession.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _run(_session.initialize);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _session.authorizationStateType;
    return Scaffold(
      backgroundColor: const Color(0xFF17212B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF232E3C),
        foregroundColor: Colors.white,
        title: const Text('Telegram 账号'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: const Color(0xFF232E3C),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF40A7E3),
                      size: 54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _titleFor(state),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _descriptionFor(state),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF91A3B7)),
                    ),
                    const SizedBox(height: 24),
                    if (!_session.telegramConfigurationAvailable)
                      const _Notice(
                        text:
                            '尚未配置产品自己的 Telegram API 凭据。请在构建时提供 TELEGRAM_API_ID 与 TELEGRAM_API_HASH；应用不会借用官方客户端凭据。',
                      )
                    else if (state == 'waitParameters' ||
                        state == 'waitPhoneNumber') ...[
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('国际手机号，例如 +8613800138000'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => _session.sendAuthenticationCode(
                                  _phoneController.text,
                                ),
                              ),
                        child: const Text('发送验证码'),
                      ),
                    ] else if (state == 'waitCode') ...[
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('Telegram 验证码'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => _session.submitAuthenticationCode(
                                  _codeController.text,
                                ),
                              ),
                        child: const Text('验证并登录'),
                      ),
                    ] else if (state == 'waitPassword') ...[
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration(
                          (_session.authorizationState['passwordHint']
                                      ?.toString()
                                      .isNotEmpty ??
                                  false)
                              ? '密码提示：${_session.authorizationState['passwordHint']}'
                              : '两步验证密码',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => _session.submitAuthenticationPassword(
                                  _passwordController.text,
                                ),
                              ),
                        child: const Text('验证密码'),
                      ),
                    ] else if (state == 'waitRegistration') ...[
                      TextField(
                        controller: _firstNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('名字'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lastNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('姓氏（可选）'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => _session.submitRegistration(
                                  firstName: _firstNameController.text,
                                  lastName: _lastNameController.text,
                                ),
                              ),
                        child: const Text('创建 Telegram 账号'),
                      ),
                    ] else if (state == 'ready') ...[
                      const _Notice(text: 'Telegram 加密会话已授权，可以开始同步会话与消息。'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(_session.beginUpdateSync),
                        icon: const Icon(Icons.sync),
                        label: Text(
                          _session.transportStatus['updateState'] == null
                              ? '开始更新同步'
                              : '刷新更新游标',
                        ),
                      ),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      _Notice(text: _message!, isError: true),
                    ],
                    if (_busy) ...[
                      const SizedBox(height: 18),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF91A3B7)),
    filled: true,
    fillColor: const Color(0xFF17212B),
    border: const OutlineInputBorder(),
  );

  String _titleFor(String state) => switch (state) {
    'waitCode' => '输入验证码',
    'waitPassword' => '需要两步验证',
    'waitRegistration' => '完成注册',
    'ready' => '已连接 Telegram',
    _ => '连接 Telegram',
  };

  String _descriptionFor(String state) => switch (state) {
    'waitCode' => '验证码由 Telegram 发送，短期登录上下文仅保留在 Rust 内存中。',
    'ready' => '认证密钥和本地数据均由平台安全存储与 Rust 加密层管理。',
    _ => '使用独立 Rust MTProto 客户端连接，不依赖 Telegram 或 TDLib 二进制。',
  };
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : const Color(0xFF40A7E3)).withValues(
          alpha: 0.14,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? Colors.red.shade200 : const Color(0xFFB9DDF4),
        ),
      ),
    );
  }
}
