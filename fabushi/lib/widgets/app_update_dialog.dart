import 'package:flutter/material.dart';

import '../services/app_update_service.dart';

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({
    super.key,
    required this.decision,
    required this.onUpdatePressed,
    this.onLaterPressed,
    this.onSkipPressed,
  });

  final AppUpdateDecision decision;
  final Future<void> Function() onUpdatePressed;
  final VoidCallback? onLaterPressed;
  final VoidCallback? onSkipPressed;

  @override
  Widget build(BuildContext context) {
    final releaseNotes = decision.policy.releaseNotes;

    return PopScope(
      canPop: !decision.isForce,
      child: AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: decision.isForce
                    ? const Color(0x33EF4444)
                    : const Color(0x3322C55E),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                decision.isForce ? '必须更新' : '建议更新',
                style: TextStyle(
                  color: decision.isForce
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF86EFAC),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              decision.policy.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '当前 ${decision.currentVersion} (${decision.currentBuildNumber})  →  最新 ${decision.latestVersionLabel}',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              decision.policy.message,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '本次更新',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: releaseNotes
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• $item',
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
            if (decision.isForce) ...[
              const SizedBox(height: 16),
              const Text(
                '当前版本已不再受支持，请完成更新后继续使用。',
                style: TextStyle(
                  color: Color(0xFFFCA5A5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!decision.isForce && onLaterPressed != null)
            TextButton(
              onPressed: onLaterPressed,
              child: const Text('稍后再说'),
            ),
          if (decision.canSkip && onSkipPressed != null)
            TextButton(
              onPressed: onSkipPressed,
              child: const Text('跳过此版本'),
            ),
          FilledButton(
            onPressed: () => onUpdatePressed(),
            style: FilledButton.styleFrom(
              backgroundColor:
                  decision.isForce ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(decision.isForce ? '立即更新并继续' : '立即更新'),
          ),
        ],
      ),
    );
  }
}
