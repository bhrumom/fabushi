import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'dart:async';
import '../models/auth_model.dart';
import '../services/membership_service.dart';
import '../services/alipay_service.dart';
// import '../widgets/membership_dialog.dart';
import '../config/unified_config.dart';
import 'package:url_launcher/url_launcher.dart';class MembershipScreen extends StatefulWidget {
  const MembershipScreen({Key? key}) : super(key: key);

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  final MembershipService _membershipService = MembershipService();
  final AlipayService _alipayService = AlipayService();
  bool _isLoading = false;

  Future<void> _purchaseMembership(String priceType) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    
    if (!authModel.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先登录'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 根据平台选择合适的支付方式
      final paymentMethod = await _getPaymentMethodForPlatform();
      
      if (paymentMethod == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> result;
      
      if (paymentMethod == 'stripe') {
        result = await _membershipService.createPaymentSession(
          authModel.authToken!,
          priceType,
        );
        
        if (result['success'] == true) {
          // Stripe支付成功，跳转到支付页面
          final paymentUrl = result['paymentUrl'];
          if (paymentUrl != null && mounted) {
            _launchStripePayment(paymentUrl, result['sessionId']);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Stripe支付链接获取失败'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else if (paymentMethod == 'alipay') {
        // 根据平台类型选择支付宝支付方式
        if (kIsWeb || _isDesktopPlatform()) {
          // Web和桌面端使用电脑网站支付
          result = await _membershipService.createAlipayWebOrder(
            authModel.authToken!,
            priceType,
          );
          
          if (result['success'] == true) {
            // 跳转到支付宝电脑网站支付页面
            final paymentUrl = result['paymentUrl'];
            if (paymentUrl != null && mounted) {
              _launchAlipayWebPayment(paymentUrl, result['orderId']);
            }
          }
        } else {
          // 手机端使用支付宝APP支付
          result = await _membershipService.createAlipayOrder(
            authModel.authToken!,
            priceType,
          );
          
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
          SnackBar(
            content: Text(result['message'] ?? '购买失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('购买时发生错误: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
              leading: const Icon(Icons.payment, color: Colors.green),
              title: const Text('支付宝'),
              onTap: () => Navigator.of(context).pop('alipay'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 根据平台自动选择合适的支付方式
  Future<String?> _getPaymentMethodForPlatform() async {
    // Web和桌面端默认使用支付宝电脑网站支付
    if (kIsWeb || _isDesktopPlatform()) {
      return 'alipay';
    }
    
    // 手机端检查是否安装了支付宝，如果安装了默认使用支付宝，否则显示选择对话框
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

  /// 处理支付宝APP支付
  Future<void> _processAlipayAppPayment(Map<String, dynamic> orderResult, String token) async {
    try {
      final orderId = orderResult['orderId'];
      final orderString = orderResult['orderString'];
      
      if (orderString == null || orderString.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('支付宝订单信息不完整'),
            backgroundColor: Colors.red,
          ),
        );
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
          SnackBar(
            content: Text(payResult['message'] ?? '支付失败'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('支付宝支付异常: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 启动支付宝Web支付
  Future<void> _launchAlipayWebPayment(String paymentUrl, String orderId) async {
    try {
      final uri = Uri.parse(paymentUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        // 启动定时器检查支付状态
        _startOrderStatusCheck(orderId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法打开支付宝支付页面'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('启动支付宝支付失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
            const SnackBar(
              content: Text('支付超时，请检查支付状态'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      try {
        final authModel = Provider.of<AuthModel>(context, listen: false);
        final orderStatus = await
        _membershipService.queryAlipayOrderStatus(
          authModel.authToken!,
          orderId,
        );
        
        if (orderStatus['status'] == 'PAID') {
          timer.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('支付成功！会员已激活'),
                backgroundColor: Colors.green,
              ),
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
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        // 启动定时器检查支付状态
        _startStripeOrderStatusCheck(sessionId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法打开Stripe支付页面'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('启动Stripe支付失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
            const SnackBar(
              content: Text('支付超时，请检查支付状态'),
              backgroundColor: Colors.orange,
            ),
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
              const SnackBar(
                content: Text('支付成功！会员已激活'),
                backgroundColor: Colors.green,
              ),
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
              const SnackBar(
                content: Text('支付成功！会员已激活'),
                backgroundColor: Colors.green,
              ),
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
          const SnackBar(
            content: Text('支付状态检查超时，请稍后手动刷新'),
            backgroundColor: Colors.orange,
          ),
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
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.card_membership,
                  size: 64,
                  color: Color(0xFF667eea),
                ),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7f8c8d),
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '返回登录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    _getMembershipIcon(user),
                    size: 48,
                    color: _getMembershipColor(user),
                  ),
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
                    Text(
                      authModel.getMembershipExpiryText()!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF7f8c8d),
                      ),
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
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
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
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7f8c8d),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...priceInfo['features'].map<Widget>((feature) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green,
                                  ),
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
                              onPressed: _isLoading 
                                  ? null 
                                  : () => _purchaseMembership(priceType),
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
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
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

          const SizedBox(height: 32),
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
}