import 'dart:async';

import 'package:flutter/material.dart';

import 'web_full_app.dart' deferred as web_full_app;

class WebInstantApp extends StatefulWidget {
  const WebInstantApp({super.key});

  @override
  State<WebInstantApp> createState() => _WebInstantAppState();
}

class _WebInstantAppState extends State<WebInstantApp> {
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadAppShell());
    });
  }

  Future<void> _loadAppShell() async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    try {
      await web_full_app.loadLibrary();
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) {
      return web_full_app.WebFullApp();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '大乘',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: _InstantLanding(
        error: _error,
        onRetry: () => unawaited(_loadAppShell()),
      ),
    );
  }
}

class _InstantLanding extends StatelessWidget {
  const _InstantLanding({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1026), Color(0xFF09070B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '大乘',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '把可分享的善法资源，带到全球',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        error == null ? '正在加载首页功能...' : '加载失败，请重试',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('重试'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
