import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class Buddha3DWidget extends StatelessWidget {
  const Buddha3DWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Center(
        child: Text('3D佛像仅在Web平台可用'),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '3D佛像仅在Web平台可用',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
  }
}
