import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import '../services/app_initializer.dart';
import '../screens/home_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../services/platform_service.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _isInitialized = false;
  bool _initStarted = false;
  String? _initError;
  final PlatformService _platformService = PlatformServiceFactory.create();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure initialization runs only once.
    if (!_initStarted) {
      _initStarted = true;
      _initializeApp();
    }
  }

  Future<void> _initializeApp() async {
    try {
      // didChangeDependencies is the safe place to use Provider.of with context.
      final authModel = Provider.of<AuthModel>(context, listen: false);

      // 1. Highest priority: check for login info in the URL hash.
      final bool loggedInFromUrl = await _processUrlHash(authModel);

      // 2. If not logged in from URL, try to load from local storage.
      if (!loggedInFromUrl) {
        await authModel.loadStoredAuth();
      }

      // 3. Perform other general app initializations.
      if (!AppInitializer.isInitialized) {
        await AppInitializer.initialize();
      }

      // If we are still mounted, update state to trigger rebuild to the main UI.
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error during app initialization: $e');
      if (mounted) {
        setState(() {
          _initError = e.toString();
          _isInitialized = true; // Mark as initialized to show the error screen.
        });
      }
    }
  }

  Future<bool> _processUrlHash(AuthModel authModel) async {
    if (kIsWeb) {
      try {
        final currentUrl = _platformService.currentUrl;
        final uri = Uri.parse(currentUrl);
        if (uri.fragment.isNotEmpty) {
          final params = Uri.splitQueryString(uri.fragment);
          
          // 处理错误情况
          if (params['error'] != null) {
            final error = params['error'];
            final errorMessage = params['error_message'] ?? '发生未知错误';
            
            // 显示错误信息
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('登录失败: $errorMessage'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            
            // Clean the URL hash.
            _platformService.replaceHistoryState('/');
            return false; // 不认为登录成功
          }
          
          // 处理支付宝绑定情况
          if (params['alipay_auth_code'] != null && params['needs_binding'] == 'true') {
            final authCode = params['alipay_auth_code']!;
            final userId = params['alipay_user_id'];
            final nickname = params['alipay_nickname'] ?? '';
            final avatar = params['alipay_avatar'] ?? '';
            
            // 导航到支付宝绑定页面
            if (mounted) {
              Navigator.of(context).pushNamed(
                '/alipay-binding',
                arguments: {
                  'alipayAuthCode': authCode,
                  'alipayUserId': userId,
                  'alipayNickname': nickname,
                  'alipayAvatar': avatar,
                },
              );
            }
            
            // Clean the URL hash.
            _platformService.replaceHistoryState('/');
            return false; // 不自动登录，等待用户绑定
          }
          
          // 处理直接登录情况 - 支持支付宝登录和其他登录方式
          final token = params['token'];
          final username = params['username'];
          final loginMethod = params['login_method'] ?? 'traditional';

          if (token != null && username != null) {
            await authModel.setTokenDirectly(token, username);

            // Clean the URL hash.
            _platformService.replaceHistoryState('/');
            
            // 显示成功消息
            String welcomeMessage = '登录成功！欢迎 $username';
            if (loginMethod == 'alipay') {
              welcomeMessage = '支付宝登录成功！欢迎 $username';
            }
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(welcomeMessage),
                  backgroundColor: Colors.green,
                ),
              );
            }
            
            return true; // Signal that login was handled.
          }
        }
      } catch (e) {
        debugPrint('Error processing URL hash: $e');
      }
    }
    return false; // Signal that login was not handled.
  }

  @override
  void dispose() {
    _platformService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在初始化应用...'),
            ],
          ),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('应用初始化失败', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '发生了一个错误: \n$_initError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _initStarted = false;
                      _isInitialized = false;
                      _initError = null;
                    });
                    // didChangeDependencies will be called again and re-trigger initialization.
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Initialization is complete, show the main screen.
    return const MainNavigationScreen();
  }
}