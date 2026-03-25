import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'dart:convert';
// 仅在Web平台上导入dart:html
import 'package:universal_html/html.dart' as html;
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/auth_model.dart';
import '../services/membership_service.dart';
import '../services/alipay_service.dart';
import '../services/apple_iap_service.dart';
// import '../widgets/membership_dialog.dart';
import '../core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({Key? key}) : super(key: key);

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> with SingleTickerProviderStateMixin {
  final MembershipService _membershipService = MembershipService();
  final AlipayService _alipayService = AlipayService();
  final AppleIapService _appleIapService = AppleIapService();
  bool _isLoading = false;

  // 历史记录相关状态
  bool _isLoadingHistory = false;
  List<PurchaseRecord> _purchaseHistory = [];
  List<RedeemRecord> _redeemHistory = [];
  late TabController _tabController;

  // Web端消息监听器（仅在Web平台上使用）
  dynamic _messageListener; // 使用dynamic类型避免编译错误
  Timer? _localStorageCheckTimer;

  @override
  void initState() {
    super.initState();
    final isApplePlatform = AppleIapService.isAppleIapPlatform;
    _tabController = TabController(length: isApplePlatform ? 1 : 2, vsync: this);

    // 在Web平台上添加消息监听器
    if (kIsWeb) {
      _setupWebMessageListener();
      _setupLocalStorageListener();
    }

    // iOS 端初始化 Apple IAP
    final isIos = AppleIapService.isAppleIapPlatform;
    debugPrint('MembershipScreen: initState - isAppleIapPlatform = $isIos');
    if (isIos) {
      _initAppleIap();
    }

    // 加载历史记录
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();

    // 移除Web端消息监听器（仅在Web平台上执行）
    if (kIsWeb && _messageListener != null) {
      try {
        html.window.removeEventListener('message', _messageListener);
      } catch (e) {
        debugPrint('移除Web消息监听器失败: $e');
      }
    }
    _localStorageCheckTimer?.cancel();

    // 清理 Apple IAP 回调
    _appleIapService.onPurchaseSuccess = null;
    _appleIapService.onPurchaseError = null;

    super.dispose();
  }

  // 设置Web端消息监听器（仅在Web平台上执行）
  void _setupWebMessageListener() {
    if (kIsWeb) {
      try {
        _messageListener = (dynamic event) {
          // 使用dynamic类型和运行时类型检查
          if (event != null && event is html.Event) {
            final messageEvent = event as html.MessageEvent;
            if (messageEvent.data is Map && messageEvent.data['action'] == 'paymentSuccess') {
              // 收到支付成功消息，刷新用户信息
              _handlePaymentSuccess();
            }
          }
        };

        html.window.addEventListener('message', _messageListener);
      } catch (e) {
        debugPrint('设置Web消息监听器失败: $e');
      }
    }
  }

  // 设置localStorage监听器（仅在Web平台上执行）
  void _setupLocalStorageListener() {
    if (kIsWeb) {
      // 定期检查localStorage中的支付成功标记
      _localStorageCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        try {
          final paymentSuccessData = html.window.localStorage['paymentSuccess'];
          if (paymentSuccessData != null) {
            // 解析数据
            try {
              final data = jsonDecode(paymentSuccessData);
              debugPrint('检测到支付成功标记: $data');
            } catch (e) {
              debugPrint('解析localStorage数据失败: $e');
            }

            // 清除标记
            html.window.localStorage.remove('paymentSuccess');

            // 处理支付成功
            _handlePaymentSuccess();
          }
        } catch (e) {
          debugPrint('检查localStorage失败: $e');
        }
      });
    }
  }

  // 处理支付成功
  Future<void> _handlePaymentSuccess() async {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('支付成功！会员已激活'), backgroundColor: Colors.green));

      // 刷新用户状态
      final authModel = Provider.of<AuthModel>(context, listen: false);
      await authModel.refreshUserInfo();

      // 刷新历史记录
      _loadHistory();
    }
  }

  // 加载历史记录
  Future<void> _loadHistory() async {
    if (!mounted) return;

    final authModel = Provider.of<AuthModel>(context, listen: false);
    if (!authModel.isLoggedIn || authModel.authToken == null) {
      return;
    }

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      // 加载购买记录
      final purchaseResult = await _membershipService.getPurchaseHistory(authModel.authToken!);
      if (purchaseResult['success'] == true && purchaseResult['purchases'] != null) {
        final purchases = purchaseResult['purchases'] as List;
        setState(() {
          _purchaseHistory = purchases.map((item) => PurchaseRecord.fromJson(item)).toList();
        });
      }

      // 加载兑换记录
      final redeemResult = await _membershipService.getRedeemHistory(authModel.authToken!);
      if (redeemResult['success'] == true && redeemResult['redeems'] != null) {
        final redeems = redeemResult['redeems'] as List;
        setState(() {
          _redeemHistory = redeems.map((item) => RedeemRecord.fromJson(item)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载历史记录失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _purchaseMembership(String priceType) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);

    if (!authModel.isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录'), backgroundColor: Colors.orange));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final paymentMethod = await _getPaymentMethodForPlatform();
      debugPrint('MembershipScreen: 选定的支付方式为: $paymentMethod, 价格类型: $priceType');

      if (paymentMethod == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> result;

      if (paymentMethod == 'apple_iap') {
        // iOS 端使用 Apple IAP
        await _processAppleIapPurchase(priceType);
        return; // Apple IAP 通过回调处理结果，直接返回
      } else if (paymentMethod == 'stripe') {
        result = await _membershipService.createPaymentSession(authModel.authToken!, priceType);

        if (result['success'] == true) {
          // Stripe支付成功，跳转到支付页面
          final paymentUrl = result['paymentUrl'];
          if (paymentUrl != null && mounted) {
            _launchStripePayment(paymentUrl, result['sessionId']);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Stripe支付链接获取失败'), backgroundColor: Colors.red),
            );
          }
        }
      } else if (paymentMethod == 'alipay') {
        // 根据平台类型选择支付宝支付方式
        if (kIsWeb || _isDesktopPlatform()) {
          // Web和桌面端使用电脑网站支付
          result = await _membershipService.createAlipayWebOrder(authModel.authToken!, priceType);

          if (result['success'] == true) {
            // 跳转到支付宝电脑网站支付页面
            final paymentUrl = result['paymentUrl'];
            if (paymentUrl != null && mounted) {
              _launchAlipayWebPayment(paymentUrl, result['orderId']);
            }
          }
        } else {
          // 手机端使用支付宝APP支付
          result = await _membershipService.createAlipayOrder(authModel.authToken!, priceType);

          if (result['success'] == true) {
            // 调用支付宝APP支付
            await _processAlipayAppPayment(result, authModel.authToken!);
          }
        }
      } else {
        result = {'success': false, 'message': '不支持的支付方式'};
      }

      if (result['success'] != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '购买失败'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('购买时发生错误: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _showPaymentMethodDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择支付方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.blue),
              title: const Text('Stripe (信用卡)'),
              onTap: () => Navigator.of(context).pop('stripe'),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
              title: const Text('支付宝'),
              onTap: () => Navigator.of(context).pop('alipay'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        ],
      ),
    );
  }

  /// 根据平台自动选择合适的支付方式
  Future<String?> _getPaymentMethodForPlatform() async {
    // iOS 端使用 Apple IAP
    if (AppleIapService.isAppleIapPlatform) {
      return 'apple_iap';
    }

    // Web和桌面端默认使用支付宝电脑网站支付
    if (kIsWeb || _isDesktopPlatform()) {
      return 'alipay';
    }

    // Android 手机端检查是否安装了支付宝
    try {
      final alipayInitResult = await _alipayService.initAlipay();
      if (alipayInitResult['success'] == true) {
        return 'alipay';
      }
    } catch (e) {
      debugPrint('检查支付宝安装状态失败: $e');
    }

    // 如果支付宝不可用，显示支付方式选择对话框
    return await _showPaymentMethodDialog();
  }

  /// 检测是否为桌面平台
  bool _isDesktopPlatform() {
    if (kIsWeb) return false;

    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (e) {
      // 如果平台检测失败，默认为false
      return false;
    }
  }

  /// 初始化 Apple IAP
  Future<void> _initAppleIap() async {
    debugPrint('MembershipScreen: 开始初始化 Apple IAP...');
    final available = await _appleIapService.initialize();
    debugPrint('MembershipScreen: Apple IAP 初始化结果: $available');
    if (!available) {
      debugPrint('Apple IAP 初始化失败或不可用');
      return;
    }

    // 设置购买成功回调
    _appleIapService.onPurchaseSuccess = (PurchaseDetails purchase) async {
      if (!mounted) return;

      final authModel = Provider.of<AuthModel>(context, listen: false);
      if (authModel.authToken == null) return;

      // 向后端发送 v2 API 需要的 transactionId
      final transactionId = _appleIapService.getTransactionId(purchase);
      if (transactionId != null) {
        final result = await _membershipService.verifyAppleReceipt(
          authModel.authToken!,
          transactionId,
          purchase.productID,
        );

        if (mounted) {
          if (result['success'] == true) {
            final alreadyProcessed = result['alreadyProcessed'] == true;
            if (!alreadyProcessed && _isLoading) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('支付成功！会员已激活'), backgroundColor: Colors.green),
              );
            } else {
              debugPrint('AppleIapService: 后台续订或已处理，跳过提示弹窗 (isLoading=$_isLoading, alreadyProcessed=$alreadyProcessed)');
            }
            await authModel.refreshUserInfo();
            _loadHistory();
          } else {
            if (_isLoading) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? '会员激活失败'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    };

    // 设置购买失败回调
    _appleIapService.onPurchaseError = (String error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.orange),
      );
      setState(() => _isLoading = false);
    };
  }

  /// 处理 Apple IAP 购买
  Future<void> _processAppleIapPurchase(String priceType) async {
    final success = await _appleIapService.purchase(priceType);
    if (!success && mounted) {
      setState(() => _isLoading = false);
    }
    // 购买结果由 _initAppleIap 中设置的回调处理
  }

  /// 处理支付宝APP支付
  Future<void> _processAlipayAppPayment(Map<String, dynamic> orderResult, String token) async {
    try {
      final orderId = orderResult['orderId'];
      final orderString = orderResult['orderString'];

      if (orderString == null || orderString.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('支付宝订单信息不完整'), backgroundColor: Colors.red));
        return;
      }

      // 发起支付宝APP支付
      final payResult = await _alipayService.payWithAlipay(orderString);

      if (payResult['success'] == true) {
        // 支付成功，检查订单状态
        await _checkOrderStatus(orderId, token);
      } else {
        // 支付失败或取消
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(payResult['message'] ?? '支付失败'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('支付宝支付异常: $e'), backgroundColor: Colors.red));
    }
  }

  /// 启动支付宝Web支付
  Future<void> _launchAlipayWebPayment(String paymentUrl, String orderId) async {
    try {
      final uri = Uri.parse(paymentUrl);

      if (await canLaunchUrl(uri)) {
        // 在Web平台上使用window.open打开支付页面，使用同一标签页而不是新窗口
        if (kIsWeb) {
          html.window.open(paymentUrl, '_self');
        } else {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        // 启动定时器检查支付状态
        _startOrderStatusCheck(orderId);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开支付宝支付页面'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('启动支付宝支付失败: $e'), backgroundColor: Colors.red));
    }
  }

  /// 启动订单状态检查定时器
  void _startOrderStatusCheck(String orderId) {
    const checkInterval = Duration(seconds: 3);
    const maxChecks = 20; // 最多检查60秒
    int checkCount = 0;

    final timer = Timer.periodic(checkInterval, (timer) async {
      checkCount++;

      if (checkCount >= maxChecks) {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('支付超时，请检查支付状态'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      try {
        final authModel = Provider.of<AuthModel>(context, listen: false);
        final orderStatus = await _membershipService.queryAlipayOrderStatus(
          authModel.authToken!,
          orderId,
        );

        if (orderStatus['status'] == 'PAID') {
          timer.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('支付成功！会员已激活'), backgroundColor: Colors.green),
            );
            // 刷新用户状态
            await authModel.refreshUserInfo();
          }
        }
      } catch (e) {
        debugPrint('检查订单状态失败: $e');
      }
    });
  }

  /// 启动Stripe支付
  Future<void> _launchStripePayment(String paymentUrl, String sessionId) async {
    try {
      final uri = Uri.parse(paymentUrl);

      if (await canLaunchUrl(uri)) {
        // 在Web平台上使用window.open打开支付页面，使用同一标签页而不是新窗口
        if (kIsWeb) {
          html.window.open(paymentUrl, '_self');
        } else {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        // 启动定时器检查支付状态
        _startStripeOrderStatusCheck(sessionId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开Stripe支付页面'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('启动Stripe支付失败: $e'), backgroundColor: Colors.red));
    }
  }

  /// 启动Stripe订单状态检查定时器
  void _startStripeOrderStatusCheck(String sessionId) {
    const checkInterval = Duration(seconds: 3);
    const maxChecks = 20; // 最多检查60秒
    int checkCount = 0;

    final timer = Timer.periodic(checkInterval, (timer) async {
      checkCount++;

      if (checkCount >= maxChecks) {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('支付超时，请检查支付状态'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      try {
        final authModel = Provider.of<AuthModel>(context, listen: false);
        final orderStatus = await _membershipService.queryStripeSessionStatus(
          authModel.authToken!,
          sessionId,
        );

        if (orderStatus['status'] == 'complete') {
          timer.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('支付成功！会员已激活'), backgroundColor: Colors.green),
            );
            // 刷新用户状态
            await authModel.refreshUserInfo();
          }
        }
      } catch (e) {
        debugPrint('检查Stripe订单状态失败: $e');
      }
    });
  }

  /// 检查订单状态
  Future<void> _checkOrderStatus(String orderId, String token) async {
    try {
      const maxRetries = 10;
      const retryDelay = Duration(seconds: 2);

      for (int i = 0; i < maxRetries; i++) {
        await Future.delayed(retryDelay);

        final orderStatus = await _membershipService.queryAlipayOrderStatus(token, orderId);

        if (orderStatus['status'] == 'PAID') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('支付成功！会员已激活'), backgroundColor: Colors.green),
            );
            // 刷新用户状态
            final authModel = Provider.of<AuthModel>(context, listen: false);
            await authModel.refreshUserInfo();
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支付状态检查超时，请稍后手动刷新'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint('检查订单状态失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('会员中心'),
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
          child: Consumer<AuthModel>(
            builder: (context, authModel, child) {
              if (!authModel.isLoggedIn) {
                return _buildLoginPrompt();
              }

              return _buildMembershipView(authModel);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.card_membership, size: 64, color: Color(0xFF667eea)),
                const SizedBox(height: 24),
                const Text(
                  '请先登录',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2c3e50),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '登录后可以购买会员，享受更多高级功能',
                  style: TextStyle(fontSize: 14, color: Color(0xFF7f8c8d)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    '返回登录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipView(AuthModel authModel) {
    final user = authModel.currentUser!;
    final membershipPrices = _membershipService.getMembershipPrices();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 当前会员状态卡片
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(_getMembershipIcon(user), size: 48, color: _getMembershipColor(user)),
                  const SizedBox(height: 16),
                  Text(
                    '当前状态: ${authModel.getMembershipStatusText()}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2c3e50),
                    ),
                  ),
                  if (authModel.getMembershipExpiryText() != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getExpiryColor(authModel.getMembershipDaysRemaining()),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        authModel.getMembershipExpiryText()!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (authModel.currentUser?.membershipExpiry != null)
                      Text(
                        '具体到期时间: ${_formatDateTime(authModel.currentUser!.membershipExpiry!)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF7f8c8d)),
                      ),
                  ],
                  if (!user.hasPremiumMembership) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '升级会员，享受更多功能！',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF667eea),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 会员套餐列表
          const Text(
            '选择会员套餐',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),

          ...membershipPrices.entries.map((entry) {
            final priceType = entry.key;
            final priceInfo = entry.value;
            final isRecommended = priceType == 'yearly';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: isRecommended ? 8 : 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isRecommended
                      ? const BorderSide(color: Color(0xFF667eea), width: 2)
                      : BorderSide.none,
                ),
                child: Stack(
                  children: [
                    if (isRecommended)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF667eea),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '推荐',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                priceInfo['name'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2c3e50),
                                ),
                              ),
                              Text(
                                priceInfo['price'],
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF667eea),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '有效期: ${priceInfo['duration']}',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF7f8c8d)),
                          ),
                          const SizedBox(height: 16),
                          ...priceInfo['features'].map<Widget>((feature) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2c3e50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () => _purchaseMembership(priceType),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRecommended
                                    ? const Color(0xFF667eea)
                                    : Colors.grey[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      user.hasPremiumMembership ? '续费' : '立即购买',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          // iOS 端显示"恢复购买"按钮（App Store 审核要求）
          if (AppleIapService.isAppleIapPlatform) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                await _appleIapService.restorePurchases();
                // 结果通过回调处理
              },
              icon: const Icon(Icons.restore, color: Colors.white70),
              label: const Text('恢复购买', style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '自动续期订阅说明',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• 订阅服务及价格会显示在上方的各个套餐中。\n'
                    '• 付款：用户确认购买并从iTunes账户扣款。\n'
                    '• 续订：苹果iTunes账户会在到期前24小时内扣费，扣费成功后订阅周期顺延。\n'
                    '• 取消续订：如需取消，请在当前周期到期前24小时，前往Apple ID设置中关闭自动续订。',
                    style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => launchUrl(Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/')),
                        child: const Text('用户协议 (EULA)', style: TextStyle(color: Colors.white, fontSize: 12, decoration: TextDecoration.underline, decorationColor: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () => launchUrl(Uri.parse('https://flutter.ombhrum.com/privacy')),
                        child: const Text('隐私政策', style: TextStyle(color: Colors.white, fontSize: 12, decoration: TextDecoration.underline, decorationColor: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // 历史记录部分
          _buildHistorySection(),
        ],
      ),
    );
  }

  IconData _getMembershipIcon(User user) {
    if (user.isAdmin) return Icons.admin_panel_settings;
    if (user.isPremiumMember) return Icons.workspace_premium;
    if (user.isTrialMember) return Icons.free_breakfast;
    return Icons.person;
  }

  Color _getMembershipColor(User user) {
    if (user.isAdmin) return Colors.purple;
    if (user.isPremiumMember) return Colors.amber;
    if (user.isTrialMember) return Colors.blue;
    return Colors.grey;
  }

  // 构建历史记录部分
  Widget _buildHistorySection() {
    return Container(
      height: 400,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                '历史记录',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2c3e50),
                ),
              ),
            ),
            if (_isLoadingHistory)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF667eea),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF667eea),
                      tabs: [
                        const Tab(text: '购买记录'),
                        if (!AppleIapService.isAppleIapPlatform) const Tab(text: '兑换记录'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPurchaseHistoryList(),
                          if (!AppleIapService.isAppleIapPlatform) _buildRedeemHistoryList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 构建购买记录列表
  Widget _buildPurchaseHistoryList() {
    if (_purchaseHistory.isEmpty) {
      return const Center(child: Text('暂无购买记录'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _purchaseHistory.length,
      itemBuilder: (context, index) {
        final record = _purchaseHistory[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              _getPaymentMethodIcon(record.paymentMethod),
              color: const Color(0xFF667eea),
            ),
            title: Text(
              record.planDisplayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('订单号: ${record.orderId}'),
                Text('购买时间: ${_formatDateTime(DateTime.parse(record.purchasedAt))}'),
                Text('金额: ¥${record.amount}'),
                Text('支付方式: ${_getPaymentMethodName(record.paymentMethod)}'),
                if (record.status != null)
                  Text(
                    '状态: ${_getStatusText(record.status!)}',
                    style: TextStyle(
                      color: _getStatusColor(record.status!),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: Icon(_getStatusIcon(record.status), color: _getStatusColor(record.status)),
          ),
        );
      },
    );
  }

  // 构建兑换记录列表
  Widget _buildRedeemHistoryList() {
    if (_redeemHistory.isEmpty) {
      return const Center(child: Text('暂无兑换记录'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _redeemHistory.length,
      itemBuilder: (context, index) {
        final record = _redeemHistory[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.card_giftcard, color: Colors.green),
            title: Text(record.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('兑换码: ${record.code}'),
                Text('兑换时间: ${_formatDateTime(DateTime.parse(record.redeemedAt))}'),
                Text('增加天数: ${record.days}天'),
              ],
            ),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
        );
      },
    );
  }

  // 获取支付方式图标
  IconData _getPaymentMethodIcon(String paymentMethod) {
    switch (paymentMethod) {
      case 'alipay':
        return Icons.account_balance_wallet;
      case 'stripe':
        return Icons.credit_card;
      case 'wechat':
        return Icons.chat_bubble;
      case 'apple':
      case 'apple_iap':
        return Icons.apple;
      default:
        return Icons.account_balance_wallet;
    }
  }

  // 获取支付方式名称
  String _getPaymentMethodName(String paymentMethod) {
    switch (paymentMethod) {
      case 'alipay':
        return '支付宝';
      case 'stripe':
        return '信用卡';
      case 'wechat':
        return '微信支付';
      case 'apple':
      case 'apple_iap':
        return 'Apple 支付';
      default:
        return paymentMethod == 'unknown' ? '未知' : paymentMethod;
    }
  }

  // 获取状态文本
  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'pending':
        return '待支付';
      case 'failed':
        return '失败';
      case 'cancelled':
        return '已取消';
      default:
        return status;
    }
  }

  // 获取状态颜色
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // 获取状态图标
  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'failed':
        return Icons.error;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  // 获取到期时间颜色
  Color _getExpiryColor(int? daysRemaining) {
    if (daysRemaining == null) return Colors.grey;
    if (daysRemaining < 0) return Colors.red;
    if (daysRemaining <= 7) return Colors.orange;
    if (daysRemaining <= 30) return Colors.yellow;
    return Colors.green;
  }

  // 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    dateTime = dateTime.toLocal(); // 转换为本地时间显示
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
