import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io' show Platform;
import '../services/platform_service.dart';

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


  Future<void> _handleAlipayCallback(String authCode) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    
    // 尝试支付宝登录，如果是新用户则自动注册
    try {
      final success = await authModel.alipayRegister('', '', authCode);
      
      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('支付宝登录成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('支付宝登录错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('支付宝登录失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 处理macOS平台的支付宝回调
  Future<void> _handleMacOSAlipayCallback(String url) async {
    debugPrint('收到macOS支付宝回调: $url');
    
    try {
      // 解析自定义scheme URL
      Map<String, String> params = {};
      
      // 移除 scheme 部分
      String urlWithoutScheme = url.replaceFirst('globaldharma://', '');
      
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
            SnackBar(
              content: Text('支付宝登录失败: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // 检查是否包含支付宝授权码
      if (params.containsKey('alipay_auth_code')) {
        final authCode = params['alipay_auth_code']!;
        debugPrint('提取到支付宝授权码: $authCode');
        debugPrint('所有参数: $params'); // 添加调试信息
        
        // 检查是否直接包含token（已存在用户）
        if (params.containsKey('token')) {
          final token = params['token']!;
          final username = params['username']!;
          
          debugPrint('macOS支付宝登录成功，用户已存在: $username');
          
          // 直接使用token登录
          final authModel = Provider.of<AuthModel>(context, listen: false);
          await authModel.loginWithToken(token, username);
          
          if (mounted) {
            Navigator.of(context).pop(); // 返回主界面
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('支付宝登录成功！欢迎 $username'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // 新用户，使用支付宝用户信息自动注册
          final alipayUserId = params['alipay_user_id'] ?? '';
          final alipayNickname = params['alipay_nickname'] ?? '支付宝用户';
          final alipayAvatar = params['alipay_avatar'] ?? '';
          
          debugPrint('macOS支付宝新用户注册: $alipayNickname ($alipayUserId)');
          
          // 使用支付宝用户信息自动注册并登录
          final authModel = Provider.of<AuthModel>(context, listen: false);
          final success = await authModel.alipayRegister(
            alipayNickname, // 使用支付宝昵称作为用户名
            '$alipayUserId@alipay.user', // 生成邮箱
            authCode,
          );
          
          debugPrint('支付宝注册结果: success=$success, error=${authModel.error}');
          
          if (success && mounted) {
            Navigator.of(context).pop(); // 返回主界面
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('支付宝登录成功！欢迎 $alipayNickname'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (mounted) {
            // 注册失败，显示错误信息
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authModel.error ?? '支付宝登录失败，请重试'),
                backgroundColor: Colors.red,
              ),
            );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('处理支付宝回调失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
            SnackBar(
              content: Text(result['error'] ?? '获取支付宝登录链接失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('支付宝登录出错: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        SnackBar(
          content: Text(authModel.error ?? '登录失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 标题
                        const Text(
                          '🙏 全球法布施',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2c3e50),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '登录您的账户',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF7f8c8d),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // 用户名输入框
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: '用户名或邮箱',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
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
                          decoration: InputDecoration(
                            labelText: '密码',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
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
                            return ElevatedButton(
                              onPressed: authModel.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667eea),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: authModel.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      '登录',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // 支付宝登录按钮
                        Consumer<AuthModel>(
                          builder: (context, authModel, child) {
                            return ElevatedButton.icon(
                              onPressed: authModel.isLoading ? null : _handleAlipayLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1677FF), // 支付宝蓝色
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.account_balance_wallet), // 使用钱包图标代替支付图标
                              label: const Text(
                                '支付宝登录',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // 分割线
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                '或',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 注册按钮
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Color(0xFF667eea)),
                          ),
                          child: const Text(
                            '创建新账户',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF667eea),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 游客模式按钮
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // 返回主界面，以游客身份使用
                          },
                          child: Text(
                            '以游客身份继续',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
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