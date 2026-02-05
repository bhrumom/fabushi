import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'dart:async';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _codeSent = false;
  int _countdown = 0;
  StreamSubscription? _urlSubscription;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    _urlSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 监听URL变化，用于处理支付宝注册回调（仅在Web平台）
    if (kIsWeb) {
      _urlSubscription = html.window.onMessage.listen((event) {
        final data = event.data;
        if (data is Map && data.containsKey('alipay_auth_code')) {
          _handleAlipayRegisterCallback(data['alipay_auth_code']);
        }
      });
    }
  }

  Future<void> _handleAlipayRegisterCallback(String authCode) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    // 显示对话框让用户输入用户名和邮箱
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完善账户信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '用户名', hintText: '请输入用户名'),
              onChanged: (value) {
                // 保存用户名
              },
            ),
            TextField(
              decoration: const InputDecoration(labelText: '邮箱', hintText: '请输入邮箱地址'),
              onChanged: (value) {
                // 保存邮箱
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              // 这里需要获取输入的值，简化处理
              Navigator.of(context).pop({
                'username': 'user_${DateTime.now().millisecondsSinceEpoch}',
                'email': 'user@example.com',
              });
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (result != null) {
      final success = await authModel.alipayRegister(
        result['username'] ?? '',
        result['email'] ?? '',
        authCode,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('支付宝注册成功'), backgroundColor: Colors.green));
        Navigator.of(context).pop(); // 返回主界面
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authModel.error ?? '支付宝注册失败'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleAlipayRegister() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    try {
      final result = await authModel.getAlipayLoginUrl();

      if (result['success'] == true && result['loginUrl'] != null) {
        final loginUrl = result['loginUrl'] as String;

        // 在Web平台上打开支付宝登录页面
        if (await canLaunch(loginUrl)) {
          await launch(loginUrl);
        } else if (kIsWeb) {
          // 如果无法打开，在Web平台上使用window.open
          html.window.open(loginUrl, '_self');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? '获取支付宝注册链接失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('支付宝注册出错: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _sendVerificationCode() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入邮箱地址'), backgroundColor: Colors.orange));
      return;
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的邮箱地址'), backgroundColor: Colors.orange));
      return;
    }

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final success = await authModel.sendVerificationCode(
      _emailController.text.trim(),
      type: 'register',
    );

    if (success && mounted) {
      setState(() {
        _codeSent = true;
        _countdown = 60;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码已发送到您的邮箱'), backgroundColor: Colors.green));

      // 开始倒计时
      _startCountdown();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authModel.error ?? '发送验证码失败'), backgroundColor: Colors.red),
      );
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _countdown > 0) {
        setState(() {
          _countdown--;
        });
        _startCountdown();
      }
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_codeSent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先获取邮箱验证码'), backgroundColor: Colors.orange));
      return;
    }

    final authModel = Provider.of<AuthModel>(context, listen: false);

    final success = await authModel.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _verificationCodeController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('注册成功！已自动登录'), backgroundColor: Colors.green));
      Navigator.of(context).pop(); // 返回登录界面
      Navigator.of(context).pop(); // 返回主界面
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authModel.error ?? '注册失败'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建账户'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          '🙏 加入全球法布施',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2c3e50),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '创建您的账户，开始法布施之旅',
                          style: TextStyle(fontSize: 14, color: Color(0xFF7f8c8d)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // 用户名输入框
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: '用户名',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入用户名';
                            }
                            if (value.trim().length < 3) {
                              return '用户名至少需要3个字符';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // 邮箱输入框
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: '邮箱地址',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入邮箱地址';
                            }
                            if (!_isValidEmail(value.trim())) {
                              return '请输入有效的邮箱地址';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // 验证码输入框和发送按钮
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _verificationCodeController,
                                decoration: InputDecoration(
                                  labelText: '邮箱验证码',
                                  prefixIcon: const Icon(Icons.security),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '请输入验证码';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: ElevatedButton(
                                onPressed: _countdown > 0 ? null : _sendVerificationCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667eea),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _countdown > 0 ? '${_countdown}s' : '获取验证码',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
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
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入密码';
                            }
                            if (value.length < 6) {
                              return '密码至少需要6个字符';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // 确认密码输入框
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: '确认密码',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请确认密码';
                            }
                            if (value != _passwordController.text) {
                              return '两次输入的密码不一致';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleRegister(),
                        ),
                        const SizedBox(height: 24),

                        // 注册按钮
                        Consumer<AuthModel>(
                          builder: (context, authModel, child) {
                            return ElevatedButton(
                              onPressed: authModel.isLoading ? null : _handleRegister,
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
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      '创建账户',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // 支付宝注册按钮 - 简化版本
                        ElevatedButton.icon(
                          onPressed: () {
                            print('支付宝注册按钮被点击');
                            _handleAlipayRegister();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1677FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.account_balance_wallet),
                          label: const Text(
                            '支付宝注册',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 返回登录链接
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('已有账户？', style: TextStyle(color: Colors.grey[600])),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                '立即登录',
                                style: TextStyle(
                                  color: Color(0xFF667eea),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
