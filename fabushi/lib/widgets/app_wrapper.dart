import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import '../services/app_initializer.dart';
import '../services/app_settings.dart';
import '../services/eula_service.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/eula_screen.dart';
import '../services/platform_service.dart';
import '../widgets/model_selection_dialog.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _isInitialized = false;
  bool _initStarted = false;
  String? _initError;
  bool _needsModelSetup = false;
  bool _needsEula = false;
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
      
      // 4. 检查是否需要 EULA 同意
      final needsEula = !await EulaService.isAccepted();
      
      // 5. 检查是否需要模型设置引导
      final needsModelSetup = await AppSettings.isFirstLaunch() && 
                              !await AppSettings.isModelSetupComplete();

      // If we are still mounted, update state to trigger rebuild to the main UI.
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _needsEula = needsEula;
          _needsModelSetup = needsModelSetup;
        });
        
        // 首先检查 EULA
        if (needsEula) {
          await _showEulaScreen();
        }
        
        // 然后显示模型选择引导
        if (needsModelSetup && mounted) {
          _showModelSetupDialog();
        }
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
  
  /// 显示 EULA 同意页面
  Future<void> _showEulaScreen() async {
    if (!mounted) return;
    
    final accepted = await EulaScreen.checkAndShow(context);
    
    if (mounted) {
      setState(() => _needsEula = !accepted);
    }
  }

  /// 显示首次启动模型选择引导
  Future<void> _showModelSetupDialog() async {
    // 延迟一下，确保 UI 已经完全渲染
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final result = await ModelSelectionDialog.show(
      context,
      isFirstLaunch: true,
    );
    
    // 无论是否选择了模型，都标记首次启动已完成
    await AppSettings.setFirstLaunchComplete();
    
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 模型设置完成'),
          backgroundColor: Colors.green,
        ),
      );
    }
    
    if (mounted) {
      setState(() {
        _needsModelSetup = false;
      });
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
                SnackBar(content: Text(welcomeMessage), backgroundColor: Colors.green),
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
            children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在初始化应用...')],
          ),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    '应用初始化失败',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '发生了一个错误: \n$_initError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _initStarted = false;
                        _isInitialized = false;
                        _initError = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF667eea),
                    ),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Initialization is complete, show the main screen.
    return const MainNavigationScreen();
  }
}
