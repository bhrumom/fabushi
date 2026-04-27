import re

with open('/Users/gloriachan/Documents/fabushi/fabushi/lib/screens/douyin_login_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove imports
content = re.sub(r"import '../services/firebase_auth_service.dart';\n", "", content)
content = re.sub(r"import '../services/firebase_rest_auth_service.dart';\n", "", content)
content = re.sub(r"import '../widgets/recaptcha_dialog.dart';\n", "", content)

# Remove state variables
content = re.sub(r"  // 手机号登录相关\n  final _phoneController(?:.*?)final _firebaseRestAuth = FirebaseRestAuthService\(\);\n", "", content, flags=re.DOTALL)
content = re.sub(r"  // 登录模式：false = 手机号登录, true = 账号密码登录\n  bool _isPasswordMode = false;\n", "", content, flags=re.DOTALL)

content = re.sub(r"  bool _codeSent = false;\n", "", content)
content = re.sub(r"  int _countdown = 0;\n", "", content)
content = re.sub(r"  Timer\? _timer;\n", "", content)

# Remove dispose items
content = re.sub(r"    _phoneController\.dispose\(\);\n", "", content)
content = re.sub(r"    _codeController\.dispose\(\);\n", "", content)
content = re.sub(r"    _timer\?\.cancel\(\);\n", "", content)

# Remove phone login getters and methods
content = re.sub(r"  bool get _canSendCode =>\n      _phoneController\.text\.length >= 11 && _countdown == 0 && !_isLoading;\n", "", content, flags=re.DOTALL)
content = re.sub(r"  bool get _canPhoneLogin =>\n      _codeSent &&\n      _codeController\.text\.length == 6 &&\n      _agreedToTerms &&\n      !_isLoading;\n", "", content, flags=re.DOTALL)

# Find start of phone logic block
start_idx = content.find("  String _formatPhoneNumber(String phone) {")
end_idx = content.find("  // ==================== 账号密码登录逻辑 ====================")
if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + content[end_idx:]

# Replace _buildHeader
content = re.sub(r"        Text\(\n          _isPasswordMode \? '账号密码登录' : '手机号快捷登录',\n          style: TextStyle\(\n            fontSize: 14,\n            color: Colors\.white\.withOpacity\(0\.6\),\n          \),\n        \),", r"""        Text(
          '账号密码登录',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
          ),
        ),""", content)

# Replace build input areas
content = re.sub(r"              // 根据模式显示不同的输入区域.*?              if \(_errorMessage != null\) \.\.\.\[", r"""              // 根据模式显示不同的输入区域
              _buildUsernameInput(),
              const SizedBox(height: 16),
              _buildPasswordInput(),
              // 错误信息
              if (_errorMessage != null) ...[""", content, flags=re.DOTALL)

# Delete _buildPhoneInput and _buildCodeInput
content = re.sub(r"  Widget _buildPhoneInput\(\) \{.*?  Widget _buildUsernameInput\(\) \{", r"  Widget _buildUsernameInput() {", content, flags=re.DOTALL)

# Replace buildLoginButton
content = re.sub(r"    final canLogin = _isPasswordMode \? _canPasswordLogin : _canPhoneLogin;\n    final onLogin = _isPasswordMode \? _passwordLogin : _phoneLogin;\n\n    return AnimatedBuilder\(", r"""    final canLogin = _canPasswordLogin;
    final onLogin = _passwordLogin;

    return AnimatedBuilder(""", content, flags=re.DOTALL)

content = re.sub(r"                        _isPasswordMode \? '🔐 登录' : '✨ 一键登录 ✨'", r"                        '🔐 登录'", content)

# Remove toggle mode button
content = re.sub(r"            const SizedBox\(width: 48\);\n            // 切换登录模式\n            _buildOtherLoginButton\(\n              icon: _isPasswordMode \? '📱' : '🔐',\n              label: _isPasswordMode \? '手机号登录' : '账号密码',\n              onTap: _toggleLoginMode,\n            \),", "", content, flags=re.DOTALL)

# Remove _toggleLoginMode method
content = re.sub(r"  // ==================== 切换登录模式 ====================\n\n  void _toggleLoginMode\(\) \{.*?\n  \}\n", "", content, flags=re.DOTALL)


with open('/Users/gloriachan/Documents/fabushi/fabushi/lib/screens/douyin_login_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
