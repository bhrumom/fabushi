import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;

class AlipayBindingScreen extends StatefulWidget {
  const AlipayBindingScreen({Key? key}) : super(key: key);

  @override
  State<AlipayBindingScreen> createState() => _AlipayBindingScreenState();
}

class _AlipayBindingScreenState extends State<AlipayBindingScreen> {
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _alipayData;

  @override
  void initState() {
    super.initState();
    _checkUrlParams();
  }

  void _checkUrlParams() {
    if (kIsWeb) {
      try {
        final uri = Uri.parse(html.window.location.href);
        if (uri.fragment.isNotEmpty) {
          final params = Uri.splitQueryString(uri.fragment);
          
          if (params['alipay_auth_code'] != null && params['needs_binding'] == 'true') {
            setState(() {
              _alipayData = {
                'alipayAuthCode': params['alipay_auth_code'],
                'alipayUserId': params['alipay_user_id'],
                'alipayNickname': params['alipay_nickname'] ?? '',
                'alipayAvatar': params['alipay_avatar'] ?? '',
              };
            });
            
            // Clean the URL hash
            html.window.history.replaceState(null, '', '/');
          }
        }
      } catch (e) {
        debugPrint('Error checking URL params: $e');
      }
    }
  }

  Future<void> _handleAlipayLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final result = await authModel.getAlipayLoginUrl();
      
      if (result['success'] == true) {
        final loginUrl = result['loginUrl'];
        
        // 尝试使用url_launcher打开URL
        if (await canLaunch(loginUrl)) {
          await launch(loginUrl);
        } else if (kIsWeb) {
          // 如果无法打开，在Web平台上使用html.window.open作为备选
          html.window.open(loginUrl, '_blank');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('正在打开支付宝登录页面，请在弹出的窗口中完成登录'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _error = result['error'] ?? '获取支付宝登录链接失败';
        });
      }
    } catch (e) {
      setState(() {
        _error = '获取支付宝登录链接时发生错误: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('绑定支付宝'),
        backgroundColor: const Color(0xFF1677FF), // 支付宝蓝色
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1677FF),
              Color(0xFF0052D9),
            ],
          ),
        ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 支付宝图标或用户头像
                    if (_alipayData != null && _alipayData!['alipayAvatar'] != null && _alipayData!['alipayAvatar'].isNotEmpty) ...[
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1677FF), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            _alipayData!['alipayAvatar'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF1677FF),
                              child: const Icon(
                                Icons.payment,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1677FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.payment,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // 标题
                    Text(
                      _alipayData != null ? '绑定支付宝账号' : '绑定支付宝账号',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2c3e50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 说明文字
                    if (_alipayData != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1677FF).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF1677FF)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '欢迎，${_alipayData!['alipayNickname'] ?? '支付宝用户'}！',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2c3e50),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '检测到您的支付宝账号尚未绑定，请绑定现有账号或创建新账号',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF7f8c8d),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Text(
                        '绑定支付宝账号后，您可以使用支付宝快速登录，享受更便捷的支付体验。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF7f8c8d),
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    
                    // 错误信息
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // 绑定按钮
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleAlipayLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1677FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          _isLoading ? '正在获取登录链接...' : '使用支付宝登录',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 提示信息
                    const Text(
                      '点击按钮后将在新窗口中打开支付宝登录页面',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF95a5a6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}