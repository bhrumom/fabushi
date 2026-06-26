import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AlipayWebLoginScreen extends StatefulWidget {
  const AlipayWebLoginScreen({super.key, required this.loginUrl});

  final String loginUrl;

  @override
  State<AlipayWebLoginScreen> createState() => _AlipayWebLoginScreenState();
}

class _AlipayWebLoginScreenState extends State<AlipayWebLoginScreen> {
  static const _desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  late final WebViewController _controller;
  int _progress = 0;
  String? _errorMessage;

  bool get _canSetOpaqueWebViewBackground =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
          },
          onNavigationRequest: _handleNavigationRequest,
          onWebResourceError: (error) {
            if (!mounted || _isIgnoredWebViewError(error)) return;
            if (error.isForMainFrame == false) return;
            setState(() => _errorMessage = error.description);
          },
        ),
      );
    if (_canSetOpaqueWebViewBackground) {
      _controller.setBackgroundColor(const Color(0xFF0F0F0F));
    }

    _loadLoginUrlWithFreshWebViewSession();
  }

  Future<void> _loadLoginUrlWithFreshWebViewSession() async {
    try {
      await WebViewCookieManager().clearCookies();
      await _controller.clearLocalStorage();
    } catch (e) {
      debugPrint('清理支付宝网页登录缓存失败: $e');
    }

    if (!mounted) return;
    await _controller.loadRequest(Uri.parse(widget.loginUrl));
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final url = request.url;
    final uri = Uri.tryParse(url);

    if (_isAppCallbackUrl(url)) {
      Navigator.of(context).pop(url);
      return NavigationDecision.prevent;
    }

    if (uri != null && _isExternalAlipayUrl(uri)) {
      _openExternalAlipay(uri);
      return NavigationDecision.prevent;
    }

    if (uri != null && !_isWebUrl(uri)) {
      return NavigationDecision.prevent;
    }

    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    return NavigationDecision.navigate;
  }

  bool _isAppCallbackUrl(String url) {
    if (url.startsWith('com.ombhrum.fabushi://') ||
        url.startsWith('globaldharma://') ||
        url.startsWith('fabushi://')) {
      return true;
    }
    
    // Intercept web callbacks that contain the auth code
    if (url.contains('auth_code=') || url.contains('alipay_auth_code=')) {
      return true;
    }
    
    return false;
  }

  bool _isExternalAlipayUrl(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'alipays' || scheme == 'alipay' || scheme == 'intent';
  }

  bool _isWebUrl(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https' || scheme == 'about';
  }

  bool _isIgnoredWebViewError(WebResourceError error) {
    final description = error.description.toLowerCase();
    return description.contains('net::err_unknown_url_scheme') ||
        description.contains('net::err_aborted') ||
        description.contains('net::err_blocked_by_orb') ||
        description.contains('net::err_blocked_by_response');
  }

  Future<void> _openExternalAlipay(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        setState(() => _errorMessage = '无法打开支付宝，请继续使用网页登录');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '无法打开支付宝，请继续使用网页登录');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('支付宝登录'),
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 2,
            child: _progress < 100
                ? LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 2,
                    color: theme.colorScheme.primary,
                    backgroundColor: Colors.white10,
                  )
                : const SizedBox.shrink(),
          ),
          if (_errorMessage != null)
            Material(
              color: Colors.red.withValues(alpha: 0.14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
