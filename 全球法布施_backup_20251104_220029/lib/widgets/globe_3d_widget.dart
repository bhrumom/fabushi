import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

// Conditional imports
import 'globe_3d_web.dart' if (dart.library.io) 'globe_3d_mobile.dart';

class Globe3DWidget extends StatefulWidget {
  const Globe3DWidget({super.key});

  @override
  State<Globe3DWidget> createState() => Globe3DWidgetState();
}

class Globe3DWidgetState extends State<Globe3DWidget> {
  String? _iframeId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _iframeId = 'globe-iframe-${DateTime.now().millisecondsSinceEpoch}';
      registerGlobeView(_iframeId!, 'globe_stream.html');
    }
  }

  void startTransfer() {
    if (kIsWeb) {
      sendMessageToGlobe();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return HtmlElementView(viewType: _iframeId!);
    } else {
      // macOS使用iframe加载本地HTML
      return _buildNativeGlobe();
    }
  }

  Widget _buildNativeGlobe() {
    return Container(
      color: const Color(0xFF0e0c15),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.public, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              '3D地球（桌面版）',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              '请使用 flutter run -d chrome 在浏览器中查看完整3D效果',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
