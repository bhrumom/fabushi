import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';

class FirebaseLoginScreen extends StatefulWidget {
  const FirebaseLoginScreen({super.key});

  @override
  State<FirebaseLoginScreen> createState() => _FirebaseLoginScreenState();
}

class _FirebaseLoginScreenState extends State<FirebaseLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firebaseAuth = FirebaseAuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase 登录')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: '邮箱'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  ElevatedButton(onPressed: _signIn, child: const Text('登录')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('Google 登录'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    final result = await _firebaseAuth.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final result = await _firebaseAuth.signInWithGoogle();
    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
