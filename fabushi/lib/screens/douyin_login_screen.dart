import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' hide IconAlignment;
import 'dart:async';
import 'dart:io' show Platform;
import '../models/auth_model.dart';
import '../services/platform_service.dart';
import '../services/alipay_service.dart';
import '../services/alipay_auth_service.dart';
import '../core/design_system/app_theme.dart';
import 'alipay_web_login_screen.dart';

/// 统一登录页面 - 支持手机号验证码登录和账号密码登录
class DouyinLoginScreen extends StatefulWidget {
  const DouyinLoginScreen({super.key});

  @override
  State<DouyinLoginScreen> createState() => _DouyinLoginScreenState();
}

class _DouyinLoginScreenState extends State<DouyinLoginScreen>
    with SingleTickerProviderStateMixin {
  // 账号密码登录相关
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool _isLoading = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  late AnimationController _buttonAnimController;
  late Animation<double> _buttonGlow;

  // 支付宝回调相关
  StreamSubscription? _urlSubscription;
  final PlatformService _platformService = PlatformServiceFactory.create();
  bool _isAlipayWebLoginOpen = false;
  String? _pendingAlipayState;

  @override
  void initState() {
    super.initState();
    _buttonAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _buttonGlow = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _buttonAnimController, curve: Curves.easeInOut),
    );

    // 监听URL变化，用于处理支付宝登录回调
    if (kIsWeb) {
      _platformService.listenToMessages((event) {
        final data = event.data;
        if (data is Map && data.containsKey('alipay_auth_code')) {
          _handleAlipayCallback(Map<String, dynamic>.from(data));
        }
      });
    } else {
      // 监听原生回调（macOS Scheme 和 移动端 Deep Link）
      _platformService.listenToMessages((url) {
        if (url is String) {
          _handleDeepLinkAlipayCallback(url);
        }
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _buttonAnimController.dispose();
    _urlSubscription?.cancel();
    _platformService.dispose();
    super.dispose();
  }

  bool get _canPasswordLogin =>
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _agreedToTerms &&
      !_isLoading;

  bool get _shouldUseEmbeddedAlipayWebLogin {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  }

  // ==================== 账号密码登录逻辑 ====================

  Future<void> _passwordLogin() async {
    if (!_canPasswordLogin) return;

    final authModel = Provider.of<AuthModel>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await authModel.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = authModel.error ?? '登录失败');
      }
    }
  }

  // ==================== 支付宝登录逻辑 ====================

  /// 检测是否为移动端（iOS/Android）
  bool get _isMobile {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  Future<void> _handleAlipayLogin() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isMobile) {
        // 移动端：使用SDK方式
        await _handleAlipaySDKLogin(authModel);
      } else {
        // 桌面端/Web：使用网页授权方式
        await _handleAlipayWebLogin(authModel);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '支付宝登录出错: $e';
        });
      }
    }
  }

  /// 使用SDK方式进行支付宝授权登录（移动端）
  Future<void> _handleAlipaySDKLogin(AuthModel authModel) async {
    try {
      // 1. 检查支付宝是否安装
      final alipayService = AlipayService();
      final isInstalled = await alipayService.isAlipayInstalled();

      if (!isInstalled) {
        debugPrint('未安装支付宝，使用网页授权登录...');
        await _handleAlipayWebLogin(authModel);
        return;
      }

      // 2. 从后端获取授权字符串
      debugPrint('开始SDK授权登录：获取授权字符串...');
      final authStringResult = await AlipayAuthService().getAlipayAuthString();

      if (authStringResult['success'] != true ||
          authStringResult['authString'] == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = authStringResult['message'] ?? '获取授权字符串失败';
          });
        }
        return;
      }

      final authString = authStringResult['authString'] as String;
      final targetId = authStringResult['targetId'] as String?;

      // 3. 调用SDK进行授权
      debugPrint('调用支付宝SDK进行授权...');
      final authResult = await alipayService.authWithAlipay(authString);

      debugPrint('SDK授权结果: $authResult');

      if (authResult['success'] != true) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = authResult['message'] ?? '支付宝授权失败';
          });
        }
        return;
      }

      // 4. 获取auth_code，发送给后端登录
      final authCode = authResult['authCode'] as String?;
      if (authCode == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '未获取到授权码';
          });
        }
        return;
      }

      debugPrint('获取到auth_code，发送给后端登录...');
      final loginResult = await AlipayAuthService().alipaySDKLogin(
        authCode,
        targetId: targetId,
      );

      debugPrint('SDK登录结果: $loginResult');

      if (loginResult['success'] == true) {
        if (loginResult['needsRegistration'] == true) {
          // 新用户需要注册
          final alipayUser = loginResult['alipayUser'];
          if (alipayUser != null) {
            final alipayProviderSubject =
                alipayUser['providerSubject'] ??
                alipayUser['provider_subject'] ??
                alipayUser['userId'] ??
                '';
            final alipaySubjectType =
                alipayUser['subjectType'] ?? alipayUser['subject_type'];
            // 自动一键注册
            final registerResult = await authModel.alipayOneClickRegister(
              alipayProviderSubject,
              alipayUser['nickname'],
              alipayUser['avatar'],
              alipaySubjectType,
            );

            if (registerResult && mounted) {
              Navigator.of(context).pop(true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('支付宝登录成功！'),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = authModel.error ?? '注册失败';
              });
            }
          }
        } else {
          // 已有用户，直接使用token登录
          final token = loginResult['token'] as String?;
          final username = loginResult['username'] as String?;
          final userJson = loginResult['user'];

          if (token != null && username != null) {
            await authModel.loginWithToken(
              token,
              username,
              userJson: userJson is Map<String, dynamic>
                  ? userJson
                  : userJson is Map
                  ? Map<String, dynamic>.from(userJson)
                  : null,
            );
            if (mounted) {
              Navigator.of(context).pop(true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('欢迎回来，$username！'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = loginResult['message'] ?? '登录失败';
          });
        }
      }
    } catch (e) {
      debugPrint('SDK登录异常: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '支付宝登录失败: $e';
        });
      }
    }
  }

  /// 使用网页方式进行支付宝授权登录（桌面端/Web/移动端备用）
  Future<void> _handleAlipayWebLogin(AuthModel authModel) async {
    String? platform;
    if (!kIsWeb) {
      if (Platform.isMacOS) {
        platform = 'macos';
      } else if (Platform.isIOS || Platform.isAndroid) {
        platform = Platform.isIOS ? 'ios' : 'android';
      }
    }

    final result = await authModel.getAlipayLoginUrl(platform: platform);
    if (!mounted) return;

    if (result['success'] == true && result['loginUrl'] != null) {
      final loginUrl = result['loginUrl'] as String;
      _pendingAlipayState = result['state']?.toString();

      if (_shouldUseEmbeddedAlipayWebLogin) {
        debugPrint('使用内置 WebView 打开支付宝网页授权');
        _isAlipayWebLoginOpen = true;
        final callbackUrl = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => AlipayWebLoginScreen(loginUrl: loginUrl),
            fullscreenDialog: true,
          ),
        );
        _isAlipayWebLoginOpen = false;

        if (!mounted) return;
        if (callbackUrl != null && callbackUrl.isNotEmpty) {
          debugPrint('内置 WebView 捕获到 deep link: $callbackUrl');
          await _handleDeepLinkAlipayCallback(callbackUrl);
        } else {
          _pendingAlipayState = null;
          setState(() => _isLoading = false);
        }
      } else {
        final uri = Uri.parse(loginUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (kIsWeb) {
          _platformService.openUrl(loginUrl, '_self');
        } else {
          _pendingAlipayState = null;
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = '无法打开支付宝登录页面';
            });
          }
        }
      }
    } else {
      _pendingAlipayState = null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = result['error'] ?? '获取支付宝登录链接失败';
        });
      }
    }
  }

  bool _isExpectedAlipayCallback(Map<String, String> params) {
    final callbackState = params['state'];
    final pendingState = _pendingAlipayState;
    if (pendingState == null || pendingState.isEmpty) {
      debugPrint('忽略支付宝回调：当前没有待处理的登录请求');
      return false;
    }
    if (callbackState == null || callbackState.isEmpty) {
      debugPrint('忽略支付宝回调：缺少state');
      return false;
    }
    if (callbackState != pendingState) {
      debugPrint('忽略支付宝回调：state不匹配');
      return false;
    }
    return true;
  }

  void _clearPendingAlipayState() {
    _pendingAlipayState = null;
  }

  Future<void> _handleAlipayCallback(Map<String, dynamic> params) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    try {
      final normalizedParams = params.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
      if (!_isExpectedAlipayCallback(normalizedParams)) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _clearPendingAlipayState();

      final alipayProviderSubject =
          (params['alipay_provider_subject'] ?? params['alipay_user_id'])
              as String?;
      final alipaySubjectType = params['alipay_subject_type'] as String?;
      final alipayNickname = params['alipay_nickname'] as String?;
      final alipayAvatar = params['alipay_avatar'] as String?;
      final authCode = params['alipay_auth_code'] as String?;

      final success = await authModel.alipayOneClickRegister(
        alipayProviderSubject ?? authCode ?? '',
        alipayNickname,
        alipayAvatar,
        alipaySubjectType,
      );

      if (success && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('支付宝登录成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('支付宝登录错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('支付宝登录失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDeepLinkAlipayCallback(String url) async {
    debugPrint('收到深度链接支付宝回调: $url');

    if (_isMobile && _isAlipayWebLoginOpen && mounted) {
      _isAlipayWebLoginOpen = false;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    try {
      String decodedUrl = url.replaceAll('&amp;', '&');
      Map<String, String> params = {};

      String urlWithoutScheme = decodedUrl
          .replaceFirst('com.ombhrum.fabushi://', '')
          .replaceFirst('globaldharma://', '')
          .replaceFirst('fabushi://', '');

      final queryParams = urlWithoutScheme.split('&');
      for (final param in queryParams) {
        final separatorIndex = param.indexOf('=');
        if (separatorIndex > 0) {
          final key = param.substring(0, separatorIndex);
          final value = param.substring(separatorIndex + 1);
          params[key] = Uri.decodeComponent(value);
        }
      }

      if (params.containsKey('error') ||
          params.containsKey('alipay_auth_code')) {
        if (!_isExpectedAlipayCallback(params)) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        _clearPendingAlipayState();
      }

      if (params.containsKey('error')) {
        final errorMessage = params['error_message'] ?? '支付宝登录失败';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('支付宝登录失败: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (params.containsKey('alipay_auth_code')) {
        final authCode = params['alipay_auth_code']!;
        final alipayProviderSubject =
            params['alipay_provider_subject'] ?? params['alipay_user_id'];
        final alipaySubjectType = params['alipay_subject_type'];
        final alipayNickname = params['alipay_nickname'];
        final alipayAvatar = params['alipay_avatar'];
        final isNewUser = params['isNewUser'] == 'true';
        final token = params['token'];
        final username = params['username'];
        final userNo = params['user_no'];

        if (!mounted) return;
        final authModel = Provider.of<AuthModel>(context, listen: false);
        bool success = false;

        if (!isNewUser && token != null && username != null) {
          try {
            await authModel.loginWithToken(
              token,
              username,
              userJson: {
                'username': username,
                if (userNo != null && userNo.isNotEmpty) 'userNo': userNo,
                if (alipayProviderSubject != null &&
                    alipayProviderSubject.isNotEmpty) ...{
                  'alipayProviderSubject': alipayProviderSubject,
                  'alipayUserId': alipayProviderSubject,
                },
                if (alipaySubjectType != null && alipaySubjectType.isNotEmpty)
                  'alipaySubjectType': alipaySubjectType,
                if (alipayNickname != null && alipayNickname.isNotEmpty) ...{
                  'nickname': alipayNickname,
                  'alipayNickname': alipayNickname,
                },
                if (alipayAvatar != null && alipayAvatar.isNotEmpty) ...{
                  'avatar': alipayAvatar,
                  'alipayAvatar': alipayAvatar,
                },
              },
            );
            success = true;
          } catch (e) {
            debugPrint('使用token登录失败: $e');
            success = false;
          }
        } else {
          success = await authModel.alipayOneClickRegister(
            alipayProviderSubject ?? authCode,
            alipayNickname,
            alipayAvatar,
            alipaySubjectType,
          );
        }

        if (success && mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('支付宝登录成功！欢迎 ${authModel.currentUser?.username}'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          final error = authModel.error ?? '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.isNotEmpty ? error : '支付宝登录失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('处理macOS支付宝回调失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理支付宝回调失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==================== Apple登录逻辑 ====================

  Future<void> _handleAppleLogin() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      final authorizationCode = credential.authorizationCode;

      if (identityToken == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Apple登录失败：未获取到身份令牌';
          });
        }
        return;
      }

      final success = await authModel.appleLogin(
        identityToken: identityToken,
        authorizationCode: authorizationCode,
        email: credential.email,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Apple登录成功'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          setState(() => _errorMessage = authModel.error ?? 'Apple登录失败');
        }
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('用户取消了Apple登录');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Apple登录失败: ${e.message}';
        });
      }
    } catch (e) {
      debugPrint('Apple登录异常: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Apple登录出错: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo和标题
              _buildHeader(),
              const SizedBox(height: 60),
              // 根据模式显示不同的输入区域
              _buildUsernameInput(),
              const SizedBox(height: 16),
              _buildPasswordInput(),
              // 错误信息
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              // 登录按钮
              _buildLoginButton(),
              const SizedBox(height: 20),
              // 用户协议
              _buildAgreement(),
              const SizedBox(height: 40),
              // 其他登录方式
              _buildOtherLoginMethods(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // 应用Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: Text('🙏', style: TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '大乘',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        // 动态标题
        Text(
          '账号密码登录',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildUsernameInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: _usernameController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: const InputDecoration(
          hintText: '请输入用户名或邮箱',
          hintStyle: TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.person_outline, color: Colors.white38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildPasswordInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: '请输入密码',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white38,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _canPasswordLogin ? _passwordLogin() : null,
      ),
    );
  }

  Widget _buildLoginButton() {
    final canLogin = _canPasswordLogin;
    final onLogin = _passwordLogin;

    return AnimatedBuilder(
      animation: _buttonGlow,
      builder: (context, child) {
        return Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: canLogin
                ? LinearGradient(
                    colors: [
                      const Color(0xFFFF6B6B).withOpacity(_buttonGlow.value),
                      const Color(0xFFFFE66D).withOpacity(_buttonGlow.value),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: canLogin ? null : const Color(0xFF333333),
            borderRadius: BorderRadius.circular(26),
            boxShadow: canLogin
                ? [
                    BoxShadow(
                      color: const Color(
                        0xFFFF6B6B,
                      ).withOpacity(0.3 * _buttonGlow.value),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: canLogin ? onLogin : null,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        '🔐 登录',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgreement() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _agreedToTerms
                  ? AppTheme.primaryColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _agreedToTerms ? AppTheme.primaryColor : Colors.white38,
              ),
            ),
            child: _agreedToTerms
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Wrap(
            children: [
              Text(
                '我已阅读并同意',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: 打开用户协议
                },
                child: const Text(
                  '《用户协议》',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                ),
              ),
              Text(
                '和',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: 打开隐私政策
                },
                child: const Text(
                  '《隐私政策》',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherLoginMethods() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '其他登录方式',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
          ],
        ),
        const SizedBox(height: 16),
        // Apple登录（仅Apple平台）。符合苹果 HIG 规范，使用标准宽带文字按钮
        if (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: SignInWithAppleButton(
                onPressed: _handleAppleLogin,
                style: SignInWithAppleButtonStyle.white,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOtherLoginButton(
              icon: '💰',
              label: '支付宝',
              onTap: _handleAlipayLogin,
            ),
          ],
        ),
        const SizedBox(height: 32),
        // 游客模式
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            '以游客身份继续',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherLoginButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
