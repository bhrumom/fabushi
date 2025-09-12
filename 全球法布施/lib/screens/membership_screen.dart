import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import '../services/membership_service.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({Key? key}) : super(key: key);

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  final MembershipService _membershipService = MembershipService();
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
      // 这里可以选择支付方式
      final paymentMethod = await _showPaymentMethodDialog();
      
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
          // 在实际应用中，这里应该打开浏览器或WebView
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('支付功能开发中，敬请期待'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else if (paymentMethod == 'alipay') {
        result = await _membershipService.createAlipayOrder(
          authModel.authToken!,
          priceType,
        );
        
        if (result['success'] == true) {
          // 在实际应用中，这里应该调用支付宝SDK
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('支付宝支付功能开发中，敬请期待'),
              backgroundColor: Colors.blue,
            ),
          );
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