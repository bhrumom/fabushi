import 'package:flutter/material.dart';
import 'widgets/earth_globe_widget.dart';

void main() {
  runApp(const TestEarthGlobeApp());
}

class TestEarthGlobeApp extends StatelessWidget {
  const TestEarthGlobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3D地球测试',
      theme: ThemeData.dark(),
      home: const TestEarthGlobeScreen(),
    );
  }
}

class TestEarthGlobeScreen extends StatelessWidget {
  const TestEarthGlobeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Earth Globe 测试')),
      body: Container(
        color: Colors.black,
        child: const Center(
          child: EarthGlobeWidget(),
        ),
      ),
    );
  }
}
