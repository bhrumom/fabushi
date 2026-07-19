import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../screens/eula_screen.dart' deferred as eula;
import '../screens/main_navigation_screen.dart';
import '../services/app_initializer.dart';
import '../services/app_settings.dart';
import '../services/app_update_service.dart' deferred as app_update;
import '../services/error_report_service.dart';
import '../services/eula_service.dart' deferred as eula_service;
import '../services/platform_service.dart';
import '../widgets/app_update_dialog.dart' deferred as app_update_dialog;
import '../widgets/model_selection_dialog.dart' deferred as model_selection;
import '../widgets/startup_splash_screen.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  static bool get _modelSetupUiEnabled => false;

  bool _isInitialized = false;
  bool _initStarted = false;
  bool _isSubmittingFeedback = false;
  bool _versionCheckScheduled = false;
  String _startupPhase = '正在唤起禅境';
  String? _initError;
  bool _needsModelSetup = false;
  bool _needsEula = false;
  AppErrorReport? _initReport;
  final PlatformService _platformService = PlatformServiceFactory.create();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initStarted) {
      _initStarted = true;
      _initializeApp();
    }
  }

  void _setStartupPhase(String phase) {
    if (!mounted || _startupPhase == phase) {
      return;
    }
    setState(() => _startupPhase = phase);
  }

  void _ensureBackgroundInitialization() {
    if (AppInitializer.isInitialized) {
      return;
    }

    unawaited(
      _runStartupSideEffect(
        stage: 'background_app_initializer',
        action: AppInitializer.initialize,
      ),
    );
  }

  Future<void> _initializeApp() async {
    if (kIsWeb) {
      _initializeWebFirstPaint();
      return;
    }

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);

      _setStartupPhase('正在恢复登录状态');
      final bool loggedInFromUrl = await _processUrlHash(authModel);

      if (!loggedInFromUrl) {
        await authModel.loadStoredAuth();
      }

      _setStartupPhase('正在整理本地设置');
      _ensureBackgroundInitialization();

      await eula_service.loadLibrary();
      final needsEula = !await _guardStartupStep<bool>(
        stage: 'check_eula_acceptance',
        action: () => eula_service.EulaService.isAccepted(),
        fallbackValue: true,
      );

      bool needsModelSetup = false;
      if (_modelSetupUiEnabled) {
        final isFirstLaunch = await _guardStartupStep<bool>(
          stage: 'check_first_launch',
          action: AppSettings.isFirstLaunch,
          fallbackValue: false,
        );
        final isModelSetupComplete = await _guardStartupStep<bool>(
          stage: 'check_model_setup_complete',
          action: AppSettings.isModelSetupComplete,
          fallbackValue: true,
        );
        needsModelSetup = isFirstLaunch && !isModelSetupComplete;
      } else {
        await _runStartupSideEffect(
          stage: 'mark_first_launch_complete',
          action: AppSettings.setFirstLaunchComplete,
        );
        await _runStartupSideEffect(
          stage: 'mark_model_setup_complete',
          action: () => AppSettings.setModelSetupComplete(true),
        );
      }

      _setStartupPhase('正在展开首页');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _needsEula = needsEula;
          _needsModelSetup = needsModelSetup;
        });

        if (needsEula) {
          await _showEulaScreen();
        }

        if (needsModelSetup && mounted) {
          await _showModelSetupDialog();
        }

        _scheduleAppVersionCheck();
      }
    } catch (error, stackTrace) {
      debugPrint('Error during app initialization: $error');
      final report = await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'app_wrapper_initialize',
        source: 'AppWrapper._initializeApp',
        fatal: true,
      );
      if (mounted) {
        setState(() {
          _initError = report.errorText;
          _initReport = report;
          _isInitialized = true;
        });
      }
    }
  }

  void _initializeWebFirstPaint() {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    setState(() {
      _isInitialized = true;
      _needsEula = false;
      _needsModelSetup = false;
      _startupPhase = '正在展开首页';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_restoreWebStateAfterFirstFrame(authModel));
    });
  }

  Future<void> _restoreWebStateAfterFirstFrame(AuthModel authModel) async {
    try {
      final loggedInFromUrl = await _processUrlHash(authModel);
      if (!loggedInFromUrl) {
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) {
            return;
          }
          unawaited(authModel.loadStoredAuth());
        });
      }

      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) {
          return;
        }
        unawaited(
          _runStartupSideEffect(
            stage: 'web_mark_first_launch_complete',
            action: AppSettings.setFirstLaunchComplete,
          ),
        );
        unawaited(
          _runStartupSideEffect(
            stage: 'web_mark_model_setup_complete',
            action: () => AppSettings.setModelSetupComplete(true),
          ),
        );
      });
    } catch (error, stackTrace) {
      await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: 'web_post_first_frame_restore',
        source: 'AppWrapper._restoreWebStateAfterFirstFrame',
      );
    }
  }

  Future<T> _guardStartupStep<T>({
    required String stage,
    required Future<T> Function() action,
    required T fallbackValue,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: stage,
        source: 'AppWrapper.startupGuard',
      );
      return fallbackValue;
    }
  }

  Future<void> _runStartupSideEffect({
    required String stage,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (error, stackTrace) {
      await ErrorReportService.instance.recordError(
        error,
        stackTrace: stackTrace,
        stage: stage,
        source: 'AppWrapper.startupSideEffect',
      );
    }
  }

  void _scheduleAppVersionCheck() {
    if (kIsWeb || _versionCheckScheduled) {
      return;
    }
    _versionCheckScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted) {
          return;
        }
        await _showAppUpdateDialogIfNeeded();
      });
    });
  }

  Future<void> _showAppUpdateDialogIfNeeded() async {
    await app_update.loadLibrary();
    await app_update_dialog.loadLibrary();

    final decision = await app_update.AppUpdateService.instance
        .checkForUpdate();
    if (!mounted || decision == null) {
      return;
    }

    await app_update.AppUpdateService.instance.markPromptShown();
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !decision.isForce,
      builder: (dialogContext) {
        return app_update_dialog.AppUpdateDialog(
          decision: decision,
          onLaterPressed: decision.isForce
              ? null
              : () => Navigator.of(dialogContext).pop(),
          onSkipPressed: decision.canSkip
              ? () async {
                  await app_update.AppUpdateService.instance.markSkippedVersion(
                    decision,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                }
              : null,
          onUpdatePressed: () async {
            final launched = await app_update.AppUpdateService.instance
                .openUpdatePage(decision);
            if (!mounted) {
              return;
            }

            if (!launched) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('暂时无法打开更新入口，请稍后重试')));
              return;
            }

            if (decision.isForce) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已打开更新入口，更新完成后请重新打开应用')),
              );
              return;
            }

            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
        );
      },
    );
  }

  Future<void> _showEulaScreen() async {
    if (!mounted) return;

    await eula.loadLibrary();
    final accepted = await eula.EulaScreen.checkAndShow(context);

    if (mounted) {
      setState(() => _needsEula = !accepted);
    }
  }

  Future<void> _showModelSetupDialog() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    await model_selection.loadLibrary();
    final result = await model_selection.ModelSelectionDialog.show(
      context,
      isFirstLaunch: true,
    );

    await _runStartupSideEffect(
      stage: 'mark_first_launch_complete_after_dialog',
      action: AppSettings.setFirstLaunchComplete,
    );

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

  Future<void> _showStartupFeedbackDialog() async {
    final report = _initReport ?? ErrorReportService.instance.lastReport;
    if (report == null) {
      return;
    }

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final titleController = TextEditingController(text: report.suggestedTitle);
    final descriptionController = TextEditingController();
    final contactController = TextEditingController(
      text: authModel.currentUser?.email ?? '',
    );
    String? validationMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> handleSubmit() async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              final contact = contactController.text.trim();

              if (title.isEmpty) {
                setDialogState(() => validationMessage = '请填写问题标题');
                return;
              }

              setDialogState(() => validationMessage = null);
              if (mounted) {
                setState(() => _isSubmittingFeedback = true);
              }

              final result = await ErrorReportService.instance.submitLastReport(
                title: title,
                userDescription: description,
                contact: contact,
                authToken: authModel.authToken,
              );

              if (!mounted) return;
              setState(() => _isSubmittingFeedback = false);

              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }

              final success = result['success'] == true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? (result['message'] ?? '问题反馈已提交')
                        : (result['error'] ?? '反馈提交失败，请稍后重试'),
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                '反馈启动异常',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '提交后会自动创建 GitHub Issue，并附带已采集到的错误信息。',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        enabled: !_isSubmittingFeedback,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '问题标题',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        enabled: !_isSubmittingFeedback,
                        style: const TextStyle(color: Colors.white),
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: '补充说明（选填）',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: '比如：点击启动后立刻出现、是否刚更新版本、是否能稳定复现。',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contactController,
                        enabled: !_isSubmittingFeedback,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '联系方式（选填）',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          '已采集摘要：${report.summary}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (validationMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          validationMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmittingFeedback
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: _isSubmittingFeedback ? null : handleSubmit,
                  child: _isSubmittingFeedback
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('提交反馈'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      descriptionController.dispose();
      contactController.dispose();
    });
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
            final providerSubject =
                params['alipay_provider_subject'] ?? params['alipay_user_id'];
            final subjectType = params['alipay_subject_type'];
            final nickname = params['alipay_nickname'] ?? '';
            final avatar = params['alipay_avatar'] ?? '';

            if (mounted) {
              Navigator.of(context).pushNamed(
                '/alipay-binding',
                arguments: {
                  'alipayAuthCode': authCode,
                  'alipayProviderSubject': providerSubject,
                  'alipaySubjectType': subjectType,
                  'alipayUserId': providerSubject,
                  'alipayNickname': nickname,
                  'alipayAvatar': avatar,
                },
              );
            }

            _platformService.replaceHistoryState('/');
            return false;
          }

          final authCode = params['alipay_auth_code'] ?? params['auth_code'];
          if (authCode != null && authCode.isNotEmpty) {
            final loggedIn = await authModel.alipayLogin(
              authCode,
              params['state'],
            );
            _platformService.replaceHistoryState('/');
            if (mounted && loggedIn) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '支付宝登录成功！欢迎 ${authModel.currentUser!.displayName}',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
            return loggedIn;
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
    if (kIsWeb && _initError == null) {
      return const MainNavigationScreen();
    }

    if (!_isInitialized) {
      return StartupSplashScreen(phaseLabel: _startupPhase);
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
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      '应用初始化失败',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '发生了一个错误：\n$_initError',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (_initReport != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '已自动保存错误快照，可直接提交反馈。',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _initStarted = false;
                              _isInitialized = false;
                              _startupPhase = '正在重新唤起禅境';
                              _initError = null;
                              _initReport = null;
                              _versionCheckScheduled = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF667eea),
                          ),
                          child: const Text('重试'),
                        ),
                        OutlinedButton(
                          onPressed: _isSubmittingFeedback
                              ? null
                              : _showStartupFeedbackDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          child: _isSubmittingFeedback
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('反馈此问题'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const MainNavigationScreen();
  }
}
