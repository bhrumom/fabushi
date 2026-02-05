import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'firebase_login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io' show Platform;
import '../services/platform_service.dart';
import '../widgets/common_widgets.dart';
import '../core/design_system/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isRegisterMode = false;
  String? _errorMessage;
  StreamSubscription? _urlSubscription;
  final PlatformService _platformService = PlatformServiceFactory.create();

  @override
  void initState() {
    super.initState();
    // 监听URL变化，用于处理支付宝登录回调（Web平台和macOS平台）
    if (kIsWeb) {
      _platformService.listenToMessages((event) {
        final data = event.data;
        if (data is Map && data.containsKey('alipay_auth_code')) {
          _handleAlipayCallback(data['alipay_auth_code']);
        }
      });
    } else {
      // macOS平台监听原生回调
      _platformService.listenToMessages((url) {
        if (url is String) {
          _handleMacOSAlipayCallback(url);
        }
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _urlSubscription?.cancel();
    _platformService.dispose();
    super.dispose();
  }

  Future<void> _handleAlipayCallback(Map<String, dynamic> params) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    // 尝试支付宝一键注册（如果是新用户）或登录（如果是已存在用户）
    try {
      final alipayUserId = params['alipay_user_id'] as String?;
      final alipayNickname = params['alipay_nickname'] as String?;
      final alipayAvatar = params['alipay_avatar'] as String?;
      final authCode = params['alipay_auth_code'] as String?;

      final success = await authModel.alipayOneClickRegister(
        alipayUserId ?? authCode ?? '',
        alipayNickname,
        alipayAvatar,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('支付宝登录成功！'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('支付宝登录错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('支付宝登录失败: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // 处理macOS平台的支付宝回调
  Future<void> _handleMacOSAlipayCallback(String url) async {
    debugPrint('收到macOS支付宝回调: $url');

    try {
      // 解码 HTML 实体 (&amp; -> &)
      String decodedUrl = url.replaceAll('&amp;', '&');
      
      // 解析自定义scheme URL
      Map<String, String> params = {};

      // 移除 scheme 部分（支持两种格式）
      String urlWithoutScheme = decodedUrl
          .replaceFirst('com.ombhrum.fabushi://', '')
          .replaceFirst('globaldharma://', ''); // 保留向后兼容

      // 直接解析查询参数（无论是否有?）
      final queryParams = urlWithoutScheme.split('&');
      for (final param in queryParams) {
        if (param.contains('=')) {
          final keyValue = param.split('=');
          if (keyValue.length == 2) {
            params[keyValue[0]] = Uri.decodeComponent(keyValue[1]);
          }
        }
      }

      // 检查是否包含错误信息
      if (params.containsKey('error')) {
        final error = params['error']!;
        final errorMessage = params['error_message'] ?? '支付宝登录失败';
        debugPrint('macOS支付宝登录错误: $error - $errorMessage');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('支付宝登录失败: $errorMessage'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // 检查是否包含支付宝授权码
      if (params.containsKey('alipay_auth_code')) {
        final authCode = params['alipay_auth_code']!;
        final alipayUserId = params['alipay_user_id'];
        final alipayNickname = params['alipay_nickname'];
        final alipayAvatar = params['alipay_avatar'];
        final isNewUser = params['isNewUser'] == 'true';
        final token = params['token'];
        final username = params['username'];

        debugPrint('提取到支付宝授权码: $authCode');
        debugPrint('所有参数: $params');

        final authModel = Provider.of<AuthModel>(context, listen: false);
        bool success = false;

        // 如果是已注册用户且有token，直接使用token登录
        if (!isNewUser && token != null && username != null) {
          debugPrint('用户已注册，使用token直接登录');
          try {
            await authModel.loginWithToken(token, username);
            success = true;
          } catch (e) {
            debugPrint('使用token登录失败: $e');
            success = false;
          }
        } else {
          // 新用户，使用一键注册
          debugPrint('新用户，调用一键注册');
          success = await authModel.alipayOneClickRegister(
            alipayUserId ?? authCode,
            alipayNickname,
            alipayAvatar,
          );
        }

        debugPrint('支付宝一键注册结果: success=$success, error=${authModel.error}');

        if (success && mounted) {
          Navigator.of(context).pop(); // 返回主界面
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('支付宝登录成功！欢迎 ${authModel.currentUser?.username}'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          // 检查是否是授权码无效错误
          final error = authModel.error ?? '';
          if (error.contains('授权码code无效') ||
              error.contains('isv.code-invalid') ||
              error.contains('授权码已过期') ||
              error.contains('授权码已被使用')) {
            // 授权码无效，提示用户重新尝试
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('授权码已过期或已被使用，请重新点击支付宝登录'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: '重新登录',
                  textColor: Colors.white,
                  onPressed: () {
                    _handleAlipayOneClickRegister();
                  },
                ),
              ),
            );
          } else if (error.contains('配置错误') || error.contains('CONFIG_ERROR')) {
            // 配置错误，提示联系技术支持
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('支付宝服务配置错误，请联系技术支持'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          } else {
            // 其他错误，显示错误信息
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
          }
        }
      } else {
        debugPrint('URL中未找到支付宝授权码参数');
        debugPrint('解析到的参数: $params');
        debugPrint('原始URL: $url');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('支付宝登录回调参数错误，参数: ${params.keys.join(', ')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('处理macOS支付宝回调失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('处理支付宝回调失败: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleAlipayLogin() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    try {
      // macOS平台需要特殊处理
      String? platform;
      if (!kIsWeb && Platform.isMacOS) {
        platform = 'macos';
      }

      final result = await authModel.getAlipayLoginUrl(platform: platform);

      if (result['success'] == true && result['loginUrl'] != null) {
        final loginUrl = result['loginUrl'] as String;

        // 直接跳转到支付宝登录页面，不再经过HTML登录页面
        final uri = Uri.parse(loginUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (kIsWeb) {
          // 如果无法打开，在Web平台上使用window.open
          _platformService.openUrl(loginUrl, '_self');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? '获取支付宝登录链接失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('支付宝登录出错: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleAlipayOneClickRegister() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    try {
      // macOS平台需要特殊处理
      String? platform;
      if (!kIsWeb && Platform.isMacOS) {
        platform = 'macos';
      }

      final result = await authModel.getAlipayLoginUrl(platform: platform);

      if (result['success'] == true && result['loginUrl'] != null) {
        final loginUrl = result['loginUrl'] as String;

        // 直接跳转到支付宝登录页面，不再经过HTML登录页面
        final uri = Uri.parse(loginUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (kIsWeb) {
          // 如果无法打开，在Web平台上使用window.open
          _platformService.openUrl(loginUrl, '_self');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? '获取支付宝登录链接失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('支付宝一键注册出错: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authModel = Provider.of<AuthModel>(context, listen: false);

    final success = await authModel.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pop(); // 返回主界面
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authModel.error ?? '登录失败'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('登录', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Hero(
                tag: 'login_card',
                child: Container(
                  decoration: AppTheme.glassDecoration.copyWith(
                    color: const Color(0x40000000), // Slightly darker for better contrast
                  ),
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(40.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 标题
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '🙏 全球法布施',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '登录您的账户',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // 用户名输入框
                        TextFormField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: '用户名或邮箱',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: const Icon(Icons.person, color: Colors.white70),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入用户名或邮箱';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // 密码输入框
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: '密码',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                          ),
                          validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入密码';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 8),

                          // 忘记密码链接
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text('忘记密码？'),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 登录按钮
                          Consumer<AuthModel>(
                            builder: (context, authModel, child) {
                              return SizedBox(
                                width: double.infinity,
                                child: PrimaryButton(
                                  text: '登录',
                                  onPressed: _handleLogin,
                                  isLoading: authModel.isLoading,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // 支付宝登录按钮
                          Consumer<AuthModel>(
                            builder: (context, authModel, child) {
                              return SizedBox(
                                width: double.infinity,
                                child: AlipayButton(
                                  text: '支付宝登录',
                                  onPressed: authModel.isLoading ? null : _handleAlipayLogin,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // 支付宝一键注册按钮
                          Consumer<AuthModel>(
                            builder: (context, authModel, child) {
                              return SizedBox(
                                width: double.infinity,
                                child: AlipayButton(
                                  text: '支付宝一键注册',
                                  onPressed: authModel.isLoading
                                      ? null
                                      : _handleAlipayOneClickRegister,
                                  outlined: true,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Firebase登录按钮
                          SizedBox(
                            width: double.infinity,
                            child: SecondaryButton(
                              text: 'Firebase 登录',
                              icon: Icons.cloud,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const FirebaseLoginScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 分割线
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey[300])),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text('或', style: TextStyle(color: Colors.grey[600])),
                              ),
                              Expanded(child: Divider(color: Colors.grey[300])),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 注册按钮
                          SizedBox(
                            width: double.infinity,
                            child: SecondaryButton(
                              text: '创建新账户',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 游客模式按钮
                          TextButton(
                            onPressed: () {
                              // 检查是否可以pop，如果不能则使用pushReplacement
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else {
                                // 如果无法pop，跳转到主页
                                Navigator.of(context).pushReplacementNamed('/');
                              }
                            },
                            child: Text(
                              '以游客身份继续',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}
