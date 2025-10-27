import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:global_dharma_sharing/core/video_feed_di/video_feed_injector.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/bloc/video_feed_cubit.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/bloc/video_feed_state.dart';
import 'package:global_dharma_sharing/features/video_feed/presentation/view/video_feed_view.dart';

class VideoFeedScreen extends StatelessWidget {
  const VideoFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('法流', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: BlocProvider(
        create: (context) => videoFeedGetIt<VideoFeedCubit>(),
        child: BlocBuilder<VideoFeedCubit, VideoFeedState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '正在加载视频...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }
            
            if (state.errorMessage.isNotEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        '加载失败',
                        style: const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.errorMessage,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            
            if (state.videos.isEmpty && !state.isLoading) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_library_outlined, color: Colors.white54, size: 80),
                      const SizedBox(height: 24),
                      const Text(
                        '暂无内容',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '正在加载法布施内容...',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.read<VideoFeedCubit>().loadVideos(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新加载'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            return const VideoFeedView();
          },
        ),
      ),
    );
  }
}
