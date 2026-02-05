import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/config/app_config.dart';

/// Firebase手机验证对话框
/// 使用托管的HTML页面（Firebase JS SDK）完成reCAPTCHA验证并发送验证码
class RecaptchaDialog extends StatefulWidget {
  final String phoneNumber;
  
  const RecaptchaDialog({
    super.key,
    required this.phoneNumber,
  });

  /// 显示对话框，发送验证码后返回sessionInfo
  /// 返回值: {'success': true, 'verificationId': '...'} 或 {'success': false, 'error': '...'}
  static Future<Map<String, dynamic>?> show(BuildContext context, {required String phoneNumber}) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecaptchaDialog(phoneNumber: phoneNumber),
    );
  }

  @override
  State<RecaptchaDialog> createState() => _RecaptchaDialogState();
}

class _RecaptchaDialogState extends State<RecaptchaDialog> {
  bool _isLoading = true;
  String? _error;
  late InAppWebViewController _webViewController;

  // 使用托管的Firebase验证页面URL
  String get _verifyUrl {
    final encodedPhone = Uri.encodeComponent(widget.phoneNumber);
    // 使用Worker托管的验证页面
    return '${AppConfig.apiUrl}/phone-verify.html?phone=$encodedPhone';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        height: 500,
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white10),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '安全验证',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop({'success': false, 'error': '用户取消'}),
                    ),
                  ],
                ),
              ),
              // WebView
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(_verifyUrl)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        transparentBackground: true,
                        disableContextMenu: true,
                        supportZoom: false,
                        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
                      ),
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        
                        // 注册JavaScript处理器接收验证码发送结果
                        controller.addJavaScriptHandler(
                          handlerName: 'onCodeSent',
                          callback: (args) {
                            if (args.isNotEmpty && args[0] is Map) {
                              final result = Map<String, dynamic>.from(args[0]);
                              debugPrint('📱 验证码发送结果: $result');
                              Navigator.of(context).pop(result);
                            }
                            return null;
                          },
                        );
                      },
                      onLoadStart: (controller, url) {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                      },
                      onLoadStop: (controller, url) {
                        setState(() => _isLoading = false);
                      },
                      onReceivedError: (controller, request, error) {
                        setState(() {
                          _isLoading = false;
                          _error = '加载失败: ${error.description}';
                        });
                      },
                    ),
                    if (_isLoading)
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFFFE66D)),
                            SizedBox(height: 16),
                            Text('加载中...', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 16),
                            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() => _error = null);
                                _webViewController.reload();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFE66D),
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
