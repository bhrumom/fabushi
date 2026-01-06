import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../../models/local_work_model.dart';
import '../../../../../services/audio_stream_service.dart';

class WorksGridView extends StatefulWidget {
  final List<LocalWorkModel> works;
  final VoidCallback? onDelete;

  const WorksGridView({
    required this.works,
    this.onDelete,
    super.key,
  });

  @override
  State<WorksGridView> createState() => _WorksGridViewState();
}

class _WorksGridViewState extends State<WorksGridView> {
  String? _playingId;

  @override
  void dispose() {
    AudioStreamService.instance.stopPlayer();
    super.dispose();
  }

  Future<void> _playWork(LocalWorkModel work) async {
    if (_playingId == work.id) {
      await AudioStreamService.instance.stopPlayer();
      setState(() {
        _playingId = null;
      });
    } else {
      await AudioStreamService.instance.stopPlayer();
      final File file = File(work.filePath);
      if (await file.exists()) {
        await AudioStreamService.instance.playAudio(work.filePath);
        setState(() {
          _playingId = work.id;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件不存在')),
          );
        }
      }
    }
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
        final isPlaying = _playingId == work.id;

        return GestureDetector(
          onTap: () => _playWork(work),
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

                // Playback overlay
                if (isPlaying)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Icon(Icons.pause_circle_filled, color: Colors.white, size: 40),
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
                        const Icon(Icons.headphones, color: Colors.white, size: 14),
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
                          style: const TextStyle(color: Colors.white, fontSize: 12),
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
