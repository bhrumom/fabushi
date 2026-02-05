import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mock_auth_service.dart';

class TestInfoScreen extends StatelessWidget {
  const TestInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final testAccounts = MockAuthService.getTestAccounts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('测试信息'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 测试模式提示
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.info, color: Colors.blue, size: 24),
                            SizedBox(width: 8),
                            Text(
                              '测试模式',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2c3e50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '当前应用运行在测试模式下，所有网络请求都会被模拟处理，无需真实的网络连接。',
                          style: TextStyle(fontSize: 14, color: Color(0xFF7f8c8d)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 测试账户列表
                const Text(
                  '测试账户',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),

                ...testAccounts.map((account) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  account['type']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2c3e50),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: '邮箱: ${account['email']}\n密码: ${account['password']}',
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('账户信息已复制到剪贴板'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy),
                                  tooltip: '复制账户信息',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.email, size: 16, color: Color(0xFF7f8c8d)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    account['email']!,
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF2c3e50)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.lock, size: 16, color: Color(0xFF7f8c8d)),
                                const SizedBox(width: 8),
                                Text(
                                  account['password']!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF2c3e50),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 16),

                // 验证码信息
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.security, color: Colors.green, size: 24),
                            SizedBox(width: 8),
                            Text(
                              '验证码信息',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2c3e50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '测试验证码: 123456',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF27ae60),
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '在注册或忘记密码时，请使用上述验证码进行验证。',
                          style: TextStyle(fontSize: 14, color: Color(0xFF7f8c8d)),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 功能说明
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.help_outline, color: Colors.orange, size: 24),
                            SizedBox(width: 8),
                            Text(
                              '功能说明',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2c3e50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '• 所有网络请求都会被模拟，响应时间约1-2秒\n'
                          '• 登录后的用户信息会保存在本地\n'
                          '• 会员功能和支付功能都是模拟的\n'
                          '• 可以测试完整的用户流程',
                          style: TextStyle(fontSize: 14, color: Color(0xFF7f8c8d), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
