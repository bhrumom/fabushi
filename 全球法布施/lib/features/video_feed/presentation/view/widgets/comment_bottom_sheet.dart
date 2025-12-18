import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../../models/auth_model.dart';
import '../../../../../../models/comment_model.dart';
import '../../../../../../services/comment_service.dart';
import '../../../../../../services/video_title_service.dart';
import '../../../../../../core/design_system/app_theme.dart';
import '../../../../../../core/utils/auth_guard.dart';

class CommentBottomSheet extends StatefulWidget {
  final String videoId;
  final String? videoTitle; // 视频标题（用于感应/发愿标记）
  final String? filePath;   // 文件路径（用于统一内容ID）
  final VoidCallback? onCommentPosted;

  const CommentBottomSheet({super.key, required this.videoId, this.videoTitle, this.filePath, this.onCommentPosted});

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final CommentService _commentService = CommentService();
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _selectedTag; // 'ganying' | 'fayuan' | null

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final comments = await _commentService.getComments(widget.videoId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    // 抖音风格：发表评论前检查登录
    final hasAuth = await AuthGuard.check(context);
    if (!hasAuth) return;

    setState(() => _isSending = true);
    
    // 获取视频标题：优先使用传入的标题，否则从缓存获取
    String? videoTitle = widget.videoTitle;
    if ((videoTitle == null || videoTitle.isEmpty) && _selectedTag != null) {
      videoTitle = VideoTitleService().getVideoTitle(widget.videoId);
    }
    
    final result = await _commentService.postComment(
      widget.videoId, 
      content, 
      tag: _selectedTag,
      videoTitle: _selectedTag != null ? videoTitle : null, // 只在有标签时传标题
      filePath: widget.filePath ?? widget.videoId, // 使用 filePath 或 videoId 作为统一ID
    );
    
    if (mounted) {
      setState(() => _isSending = false);
      if (result['success']) {
        final newComment = result['comment'] as CommentModel;
        _commentController.clear();
        setState(() {
          _comments.insert(0, newComment);
          _selectedTag = null; // 重置标签选择
        });
        widget.onCommentPosted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评论发表成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? '评论发表失败，请稍后重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 顶部标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), // 占位
                Text(
                  '评论 (${_comments.length})',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 评论列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _comments.isEmpty
                    ? const Center(
                        child: Text('暂无评论，快来抢沙发吧~', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
          ),

          // 底部输入框（带标签选择）
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标签选择行
                Row(
                  children: [
                    const Text('发表为：', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 8),
                    _buildTagButton('普通评论', null),
                    const SizedBox(width: 8),
                    _buildTagButton('感应', 'ganying'),
                    const SizedBox(width: 8),
                    _buildTagButton('发愿', 'fayuan'),
                  ],
                ),
                const SizedBox(height: 8),
                // 输入行
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _selectedTag == 'ganying' 
                              ? '分享你的感应体验...'
                              : _selectedTag == 'fayuan'
                                  ? '写下你的愿望...'
                                  : '说点什么...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white10,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _postComment(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, color: AppTheme.primaryColor),
                            onPressed: _postComment,
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

  Widget _buildCommentItem(CommentModel comment) {
    return Padding(
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
                const SizedBox(height: 4),
                Text(
                  _formatDate(comment.createdAt),
                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ],
            ),
          ),
          // 暂时隐藏点赞功能，后续实现
          // Column(
          //   children: [
          //     const Icon(Icons.favorite_border, color: Colors.white38, size: 16),
          //     if (comment.likeCount > 0)
          //       Text(
          //         '${comment.likeCount}',
          //         style: const TextStyle(color: Colors.white38, fontSize: 12),
          //       ),
          //   ],
          // ),
        ],
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
}
