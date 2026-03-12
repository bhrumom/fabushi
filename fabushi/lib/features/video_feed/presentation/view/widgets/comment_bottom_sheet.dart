import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../services/audio_stream_service.dart';
import '../../../../../models/comment_model.dart';
import '../../../../../services/comment_service.dart';
import '../../../../../services/content_stats_service.dart';
import '../../../../../core/utils/auth_guard.dart';
import '../../../../../services/content_filter_service.dart';
import '../../../../../services/user_block_service.dart';
import '../../../../../widgets/report_dialog.dart';

class CommentBottomSheet extends StatefulWidget {
  final String videoId;
  final String? videoTitle;
  final String? filePath;
  final VoidCallback? onCommentPosted;

  const CommentBottomSheet({
    Key? key,
    required this.videoId,
    this.videoTitle,
    this.filePath,
    this.onCommentPosted,
  }) : super(key: key);

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final CommentService _commentService = CommentService();
  
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  String? _selectedTag;
  String? _playingCommentId;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    AudioStreamService.instance.stopPlayer();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _commentService.getComments(widget.videoId);
      if (mounted) {
        // 过滤违禁词和被屏蔽用户的评论
        final blockService = UserBlockService();
        final filtered = comments.where((c) {
          if (blockService.shouldFilter(c.userId)) return false;
          if (ContentFilterService.containsObjectionableContent(c.content)) return false;
          return true;
        }).toList();
        setState(() {
          _comments = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载评论失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _playAudio(CommentModel comment) async {
    final path = comment.attachmentPath;
    if (path == null) return;

    if (_playingCommentId == comment.id.toString()) {
      await AudioStreamService.instance.stopPlayer();
      setState(() {
        _playingCommentId = null;
      });
    } else {
      await AudioStreamService.instance.stopPlayer();
      
      // 检查文件是否存在或由于是网络路径
      bool canPlay = false;
      if (path.startsWith('http')) {
        canPlay = true;
      } else {
        final File file = File(path);
        if (await file.exists()) {
          canPlay = true;
        }
      }

      if (canPlay) {
        await AudioStreamService.instance.playAudio(path);
        setState(() {
          _playingCommentId = comment.id.toString();
        });
      } else {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('音频文件不存在或无法访问')),
           );
         }
      }
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final hasAuth = await AuthGuard.check(context);
    if (!hasAuth) return;

    try {
      final result = await _commentService.postComment(
        widget.videoId,
        content,
        tag: _selectedTag,
        contentTitle: widget.videoTitle,
        filePath: widget.filePath,
      );

      if (result['success'] == true) {
        _commentController.clear();
        setState(() => _selectedTag = null);
        FocusScope.of(context).unfocus();
        
        // 重新加载评论
        await _loadComments();
        
        widget.onCommentPosted?.call();
        
        // 更新统计数据
        ContentStatsService().incrementCommentCount(widget.videoId);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? '发布失败')),
          );
        }
      }
    } catch (e) {
      debugPrint('发布评论异常: $e');
    }
  }

  Widget _buildTagButton(String label, String? tag) {
    final isSelected = _selectedTag == tag;
    Color bgColor;
    Color textColor;
    
    if (tag == 'ganying') {
      bgColor = isSelected ? Colors.orange : Colors.orange.withOpacity(0.1);
      textColor = isSelected ? Colors.white : Colors.orange;
    } else if (tag == 'fayuan') {
      bgColor = isSelected ? Colors.purple : Colors.purple.withOpacity(0.1);
      textColor = isSelected ? Colors.white : Colors.purple;
    } else {
      bgColor = isSelected ? Colors.white24 : Colors.transparent;
      textColor = isSelected ? Colors.white : Colors.white54;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedTag = tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? (tag == 'ganying' ? Colors.orange : tag == 'fayuan' ? Colors.purple : Colors.white38)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.year}-${date.month}-${date.day}';
    }
  }

  Widget _buildCommentItem(CommentModel comment) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        ReportDialog.show(
          context,
          contentId: 'comment_${comment.id}',
          authorId: comment.userId,
          authorName: comment.displayName,
          onActionCompleted: () {
            // 屏蔽/举报后重新加载评论
            _loadComments();
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[800],
            backgroundImage: comment.avatar != null ? NetworkImage(comment.avatar!) : null,
            child: comment.avatar == null
                ? Text(
                    (comment.displayName.isNotEmpty ? comment.displayName[0] : '?').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.displayName,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    // 显示主修功课
                    if (comment.mainPractice != null && comment.mainPractice!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '@${comment.mainPractice}',
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 11),
                      ),
                    ],
                    // 显示感应/发愿标签
                    if (comment.tag != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: comment.tag == 'ganying' 
                              ? Colors.orange.withOpacity(0.2) 
                              : Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          comment.tag == 'ganying' ? '感应' : '发愿',
                          style: TextStyle(
                            color: comment.tag == 'ganying' ? Colors.orange : Colors.purple,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                if (comment.attachmentType == 'audio' && comment.attachmentPath != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _playAudio(comment),
                    child: Container(
                      width: 160,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _playingCommentId == comment.id.toString() 
                                ? Icons.pause_circle_filled 
                                : Icons.play_circle_filled,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '点击播放作品',
                            style: TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDate(comment.createdAt),
                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                Text(
                  '${_comments.length} 条评论',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10, height: 1),
          
          // 评论列表
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无评论，快来抢沙发吧',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          return _buildCommentItem(_comments[index]);
                        },
                      ),
          ),
          
          // 输入区域
          Container(
            padding: EdgeInsets.only(
              left: 16, 
              right: 16, 
              top: 12,
              bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2C),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标签选择
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTagButton('感应', 'ganying'),
                      const SizedBox(width: 12),
                      _buildTagButton('发愿', 'fayuan'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // 输入框和发送按钮
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: '善言善语...',
                            hintStyle: TextStyle(color: Colors.white30),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _postComment,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.black, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
