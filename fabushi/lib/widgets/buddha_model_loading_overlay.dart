import 'package:flutter/material.dart';

class BuddhaModelLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final double progress;
  final String label;
  final String? failureDetails;
  final VoidCallback? onRetry;

  const BuddhaModelLoadingOverlay.loading({
    super.key,
    required this.progress,
    required this.label,
  }) : isLoading = true,
       failureDetails = null,
       onRetry = null;

  const BuddhaModelLoadingOverlay.failed({
    super.key,
    required this.failureDetails,
    required this.onRetry,
  }) : isLoading = false,
       progress = 0.0,
       label = '3D佛像下载失败';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xE60B0E14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xD91A1620),
                border: Border.all(color: const Color(0x99D4AF37)),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: isLoading ? _buildLoading() : _buildFailed(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    final hasProgress = normalizedProgress > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            color: Color(0xFFFFD700),
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: hasProgress ? normalizedProgress : null,
          minHeight: 8,
          backgroundColor: const Color(0x44FFFFFF),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
        ),
        const SizedBox(height: 10),
        Text(
          hasProgress
              ? '下载进度 ${(normalizedProgress * 100).toStringAsFixed(0)}%'
              : '正在连接下载源...',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFailed(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.white70, size: 48),
        const SizedBox(height: 16),
        const Text(
          '3D佛像下载失败',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          failureDetails ?? '网络或模型文件校验失败，请稍后重试。',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
        ),
      ],
    );
  }
}
