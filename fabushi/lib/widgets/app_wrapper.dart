import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
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
  bool _initStarted = false;
  String? _initError;
  bool _needsModelSetup = false;
  bool _needsEula = false;
  final PlatformService _platformService = PlatformServiceFactory.create();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initStarted) {
      _initStarted = true;
      unawaited(_initializeNonBlockingState());
    }
  }

  Future<void> _initializeNonBlockingState() async {
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);

      // URL 登录需要即时处理；本地登录态、同步、会员刷新等不再阻塞首屏。
      final loggedInFromUrl = await _processUrlHash(authModel);
      if (!loggedInFromUrl) {
        unawaited(authModel.loadStoredAuth());
      }

      final needsEula = !await EulaService.isAccepted();
      final needsModelSetup = await AppSettings.isFirstLaunch() &&
          !await AppSettings.isModelSetupComplete();

      if (!mounted) return;
      setState(() {
        _needsEula = needsEula;
        _needsModelSetup = needsModelSetup;
      });

      // 先展示主界面，再以弹层完成合规确认与模型引导，避免启动页卡住。
      if (needsEula) {
        await _showEulaScreen();
      }

      if (needsModelSetup && mounted) {
        unawaited(_showModelSetupDialog());
      }
    } catch (e) {
      debugPrint('Error during lightweight app initialization: $e');
      if (mounted) {
        setState(() => _initError = e.toString());
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
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final result = await ModelSelectionDialog.show(
      context,
      isFirstLaunch: true,
    );

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

          if (params['error'] != null) {
            final errorMessage = params['error_message'] ?? '发生未知错误';

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('登录失败: $errorMessage'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }

            _platformService.replaceHistoryState('/');
            return false;
          }

          if (params['alipay_auth_code'] != null &&
              params['needs_binding'] == 'true') {
            final authCode = params['alipay_auth_code']!;
            final userId = params['alipay_user_id'];
            final nickname = params['alipay_nickname'] ?? '';
            final avatar = params['alipay_avatar'] ?? '';

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

            _platformService.replaceHistoryState('/');
            return false;
          }

          final token = params['token'];
          final username = params['username'];
          final loginMethod = params['login_method'] ?? 'traditional';

          if (token != null && username != null) {
            await authModel.setTokenDirectly(token, username);
            _platformService.replaceHistoryState('/');

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

            return true;
          }
        }
      } catch (e) {
        debugPrint('Error processing URL hash: $e');
      }
    }
    return false;
  }

  @override
  void dispose() {
    _platformService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF050816), Color(0xFF1B2240)],
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
                        _initError = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1B2240),
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

    return const MainNavigationScreen();
  }
}
