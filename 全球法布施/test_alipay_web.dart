import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:global_dharma_sharing/models/auth_model.dart';
import 'package:global_dharma_sharing/services/membership_service.dart';
import 'package:global_dharma_sharing/services/alipay_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthModel(),
      child: const TestAlipayWebApp(),
    ),
  );
}

class TestAlipayWebApp extends StatelessWidget {
  const TestAlipayWebApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '支付宝Web支付测试',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestAlipayWebScreen(),
    );
  }
}

class TestAlipayWebScreen extends StatefulWidget {
  const TestAlipayWebScreen({Key? key}) : super(key: key);

  @override
  State<TestAlipayWebScreen> createState() => _TestAlipayWebScreenState();
}

class _TestAlipayWebScreenState extends State<TestAlipayWebScreen> {
  final MembershipService _membershipService = MembershipService();
  final AlipayService _alipayService = AlipayService();
  bool _isLoading = false;
  String _status = '准备就绪';

  Future<void> _testAlipayWebPayment() async {
    setState(() {
      _isLoading = true;
      _status = '正在创建订单...';
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      
      // 设置测试token
      // 使用模拟登录状态
      if (!authModel.isLoggedIn) {
        // 模拟登录状态用于测试
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录进行测试')),
        );
        return;
      }

      // 创建支付宝Web订单
      final result = await _membershipService.createAlipayWebOrder(
        'test_token_123',
        'monthly',
      );

      if (result['success'] == true) {
        final paymentUrl = result['paymentUrl'];
        final orderId = result['orderId'];
        
        setState(() {
          _status = '订单创建成功，正在跳转到支付宝...';
        });

        // 启动Web支付
        await _alipayService.launchAlipayWebPayment(paymentUrl);
        
        setState(() {
          _status = '已跳转到支付宝支付页面';
        });
      } else {
        setState(() {
          _status = '订单创建失败: ${result['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _status = '发生错误: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('支付宝Web支付测试'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _status,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _testAlipayWebPayment,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('测试支付宝Web支付'),
            ),
            const SizedBox(height: 40),
            const Text(
              '测试说明：\n'
              '1. 点击按钮创建支付宝Web订单\n'
              '2. 系统会跳转到支付宝电脑网站支付页面\n'
              '3. 在支付宝页面完成支付\n'
              '4. 支付完成后返回应用',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}