import 'dart:async';

import 'package:flutter/material.dart';

import '../services/social_friend_service.dart';
import '../services/telegram/telegram_chat_session.dart';

class TelegramFriendChatScreen extends StatefulWidget {
  const TelegramFriendChatScreen({super.key, required this.friend});

  final SocialFriendContact friend;

  @override
  State<TelegramFriendChatScreen> createState() =>
      _TelegramFriendChatScreenState();
}

class _TelegramFriendChatScreenState extends State<TelegramFriendChatScreen> {
  final TelegramChatSession _session = TelegramChatSession.instance;
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_handleStateChanged);
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _session.removeListener(_handleStateChanged);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      await _session.upsertFriend(widget.friend);
    } catch (_) {}
  }

  void _handleStateChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _session.queueText(widget.friend, text);
      _composer.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('消息未进入发送队列：$error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _session.messagesForFriend(widget.friend);
    return ColoredBox(
      color: const Color(0xFF0F1722),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _session.lastError != null && !_session.isReady
                  ? _buildUnavailable()
                  : messages.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有消息',
                        style: TextStyle(color: Color(0xFF91A3B7)),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          _MessageBubble(message: messages[index]),
                    ),
            ),
            _buildComposer(),
            if (_session.storageWarning != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                color: const Color(0xFF17212B),
                child: Text(
                  _session.storageWarning!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE3B45A),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF17212B),
        border: Border(bottom: BorderSide(color: Color(0xFF223040))),
      ),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF3D8BFF),
            backgroundImage: widget.friend.avatarUrl.startsWith('http')
                ? NetworkImage(widget.friend.avatarUrl)
                : null,
            child: widget.friend.avatarUrl.startsWith('http')
                ? null
                : Text(
                    widget.friend.displayName.isEmpty
                        ? '?'
                        : widget.friend.displayName.substring(0, 1),
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friend.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _session.isReady
                      ? (_session.isPersistent
                            ? 'Rust 消息核心 · 加密本地存储'
                            : 'Rust 消息核心 · 临时会话')
                      : '正在连接消息核心…',
                  style: const TextStyle(
                    color: Color(0xFF91A3B7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailable() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          '消息核心暂不可用\n${_session.lastError}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF91A3B7)),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: const Color(0xFF17212B),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _composer,
              enabled: _session.isReady && !_sending,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _session.isReady ? '输入消息' : '正在加载消息核心',
                hintStyle: const TextStyle(color: Color(0xFF728196)),
                filled: true,
                fillColor: const Color(0xFF242F3D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _session.isReady && !_sending ? _send : null,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF40A7E3),
              disabledBackgroundColor: const Color(0xFF314152),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TelegramChatMessage message;

  @override
  Widget build(BuildContext context) {
    final time =
        '${message.sentAt.hour.toString().padLeft(2, '0')}:${message.sentAt.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: message.isOutgoing
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
        decoration: BoxDecoration(
          color: message.isOutgoing
              ? const Color(0xFF2B5278)
              : const Color(0xFF182533),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message.text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: const TextStyle(color: Color(0xFFAAB8C6), fontSize: 10),
            ),
            if (message.isOutgoing) ...[
              const SizedBox(width: 3),
              Icon(
                message.deliveryState == 'sent'
                    ? Icons.done_all
                    : Icons.schedule,
                size: 13,
                color: const Color(0xFF9CCBEE),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
