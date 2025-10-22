import 'package:flutter/material.dart';
import '../widgets/meditation_room_3d_widget.dart';

class MeditationRoomScreen extends StatelessWidget {
  const MeditationRoomScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修习室'),
        backgroundColor: Colors.brown[800],
      ),
      body: const MeditationRoom3DWidget(),
    );
  }
}
