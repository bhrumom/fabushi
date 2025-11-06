import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authModel = Provider.of<AuthModel>(context, listen: false);

    final success = await authModel.forgotPassword(_emailController.text.trim());

    if (success && mounted) {
      setState(() {
        _emailSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('重置邮件已发送，请检查您的邮箱'), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authModel.error ?? '发送重置邮件失败'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('忘记密码'),
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: _emailSent ? _buildSuccessView() : _buildFormView(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图标
          const Icon(Icons.lock_reset, size: 64, color: Color(0xFF667eea)),
          const SizedBox(height: 24),

          // 标题
          const Text(
            '重置密码',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '输入您的邮箱地址，我们将发送重置密码的链接',
            style: TextStyle(fontSize: 14, color: Color(0xFF7f8c8d)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // 邮箱输入框
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: '邮箱地址',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入邮箱地址';
              }
              if (!_isValidEmail(value.trim())) {
                return '请输入有效的邮箱地址';
              }
              return null;
            },
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleForgotPassword(),
          ),
          const SizedBox(height: 24),

          // 发送按钮
          Consumer<AuthModel>(
            builder: (context, authModel, child) {
              return ElevatedButton(
                onPressed: authModel.isLoading ? null : _handleForgotPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: authModel.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '发送重置邮件',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 返回登录链接
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('记起密码了？', style: TextStyle(color: Colors.grey[600])),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  '返回登录',
                  style: TextStyle(color: Color(0xFF667eea), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 成功图标
        const Icon(Icons.mark_email_read, size: 64, color: Colors.green),
        const SizedBox(height: 24),

        // 成功标题
        const Text(
          '邮件已发送',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2c3e50)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // 说明文字
        Text(
          '我们已向 ${_emailController.text.trim()} 发送了重置密码的邮件。\n\n请检查您的邮箱（包括垃圾邮件文件夹），并点击邮件中的链接来重置密码。',
          style: const TextStyle(fontSize: 14, color: Color(0xFF7f8c8d), height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // 重新发送按钮
        OutlinedButton(
          onPressed: () {
            setState(() {
              _emailSent = false;
            });
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: Color(0xFF667eea)),
          ),
          child: const Text(
            '重新发送',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF667eea)),
          ),
        ),
        const SizedBox(height: 16),

        // 返回登录按钮
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: const Text('返回登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
