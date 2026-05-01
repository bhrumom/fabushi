import 'package:flutter/material.dart';
import '../../../../../models/local_work_model.dart';
import '../../../../../services/audio_stream_service.dart';
import '../../../../../screens/work_player_screen.dart';

class WorksGridView extends StatefulWidget {
  final List<LocalWorkModel> works;
  final VoidCallback? onDelete;

  const WorksGridView({required this.works, this.onDelete, super.key});

  @override
  State<WorksGridView> createState() => _WorksGridViewState();
}

class _WorksGridViewState extends State<WorksGridView> {
  @override
  void dispose() {
    AudioStreamService.instance.stopPlayer();
    super.dispose();
  }

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.works.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 60, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              '还没有发布作品',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '去读诵经文发布一个吧',
              style: TextStyle(color: Colors.white30, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.8, // Slightly taller for audio cover look
      ),
      itemCount: widget.works.length,
      itemBuilder: (context, index) {
        final work = widget.works[index];

        return GestureDetector(
          onTap: () {
            // 导航到全屏播放页面
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WorkPlayerScreen(work: work)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              image: work.coverUrl != null
                  ? DecorationImage(
                      image: NetworkImage(work.coverUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                // Placeholder gradient if no cover
                if (work.coverUrl == null)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        work.title.isEmpty ? '无标题' : work.title[0],
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Footer info (Duration & Play Icon)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.headphones,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            work.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(work.durationMs),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
