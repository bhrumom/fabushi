import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/design_system/app_theme.dart';
import '../data/flashcard_repository.dart';
import '../domain/flashcard_models.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final FlashcardDeck deck;
  final FlashcardRepository? repository;

  const FlashcardStudyScreen({super.key, required this.deck, this.repository});

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  late final FlashcardRepository _repository;
  late final PageController _pageController;
  final FlutterTts _tts = FlutterTts();

  FlashcardStudyProgress? _progress;
  bool _showAnswer = false;
  bool _shuffleCards = false;
  bool _ttsEnabled = true;
  bool _autoPlay = false;
  bool _frontToBack = true;
  bool _isSpeaking = false;
  int _currentIndex = 0;
  late List<Flashcard> _cards;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FlashcardRepository();
    _cards = List<Flashcard>.from(widget.deck.cards);
    _pageController = PageController(initialPage: _currentIndex);
    unawaited(_loadProgress());
    unawaited(_initTts());
  }

  @override
  void dispose() {
    _pageController.dispose();
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final progress = await _repository.getStudyProgress(widget.deck.id);
    if (!mounted) return;
    final index = progress.currentIndex.clamp(0, max(0, _cards.length - 1));
    setState(() {
      _progress = progress;
      _currentIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
        if (_autoPlay) _goNext(speak: true);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (_) {
      if (mounted) setState(() => _ttsEnabled = false);
    }
  }

  Future<void> _saveProgress() async {
    final old = _progress ?? FlashcardStudyProgress.empty(widget.deck.id);
    final next = old.copyWith(
      currentIndex: _currentIndex,
      updatedAt: DateTime.now(),
    );
    _progress = next;
    await _repository.saveStudyProgress(next);
  }

  Future<void> _speakCurrent({bool includeAnswer = false}) async {
    if (!_ttsEnabled || _cards.isEmpty) return;
    final card = _cards[_currentIndex];
    final text = includeAnswer
        ? [
            card.front,
            card.answer,
            card.back,
          ].where((part) => part.trim().isNotEmpty).join('。')
        : (_frontToBack ? card.front : card.back);
    await _tts.stop();
    if (text.trim().isNotEmpty) await _tts.speak(text);
  }

  void _toggleFavorite() {
    final card = _cards[_currentIndex];
    final old = _progress ?? FlashcardStudyProgress.empty(widget.deck.id);
    final favorites = Set<String>.from(old.favoriteCardIds);
    if (favorites.contains(card.id)) {
      favorites.remove(card.id);
    } else {
      favorites.add(card.id);
    }
    setState(() {
      _progress = old.copyWith(
        favoriteCardIds: favorites,
        updatedAt: DateTime.now(),
      );
    });
    unawaited(_repository.saveStudyProgress(_progress!));
  }

  void _markMastered() {
    final card = _cards[_currentIndex];
    final old = _progress ?? FlashcardStudyProgress.empty(widget.deck.id);
    final mastered = Set<String>.from(old.masteredCardIds)..add(card.id);
    setState(() {
      _progress = old.copyWith(
        masteredCardIds: mastered,
        updatedAt: DateTime.now(),
      );
    });
    unawaited(_repository.saveStudyProgress(_progress!));
    _goNext();
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _showAnswer = false;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    unawaited(_saveProgress());
  }

  void _goPrevious() {
    if (_currentIndex <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goNext({bool speak = false}) {
    if (_currentIndex >= _cards.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    if (speak) {
      Future<void>.delayed(const Duration(milliseconds: 320), _speakCurrent);
    }
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget switchTile({
              required String title,
              required String subtitle,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return SwitchListTile(
                value: value,
                onChanged: (next) {
                  onChanged(next);
                  setSheetState(() {});
                  setState(() {});
                },
                title: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60),
                ),
                activeThumbColor: AppTheme.primaryColor,
              );
            }

            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF202020),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '背诵设置',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    switchTile(
                      title: '混合卡片',
                      subtitle: '打乱当前卡组顺序，适合复习。',
                      value: _shuffleCards,
                      onChanged: (next) {
                        _shuffleCards = next;
                        if (next) {
                          _cards = List<Flashcard>.from(widget.deck.cards)
                            ..shuffle();
                        } else {
                          _cards = List<Flashcard>.from(widget.deck.cards);
                        }
                        _currentIndex = 0;
                        _pageController.jumpToPage(0);
                      },
                    ),
                    switchTile(
                      title: '文字转语音',
                      subtitle: '播放当前卡片文本。',
                      value: _ttsEnabled,
                      onChanged: (next) => _ttsEnabled = next,
                    ),
                    switchTile(
                      title: '分类播放',
                      subtitle: '自动播放完成后进入下一张。',
                      value: _autoPlay,
                      onChanged: (next) => _autoPlay = next,
                    ),
                    switchTile(
                      title: '词语方向',
                      subtitle: _frontToBack ? '当前：正面 -> 答案' : '当前：答案 -> 正面',
                      value: _frontToBack,
                      onChanged: (next) => _frontToBack = next,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _restart();
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('重新启动单词卡'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mastered = _progress?.masteredCardIds.length ?? 0;
    final favorites = _progress?.favoriteCardIds ?? const <String>{};
    final card = _cards.isEmpty ? null : _cards[_currentIndex];
    final favorite = card != null && favorites.contains(card.id);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6F0),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          '${_cards.isEmpty ? 0 : _currentIndex + 1} / ${_cards.length}',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '收藏',
            onPressed: _cards.isEmpty ? null : _toggleFavorite,
            icon: Icon(
              favorite ? Icons.star : Icons.star_border,
              color: favorite ? Colors.orange : Colors.black87,
            ),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _cards.isEmpty
                          ? 0
                          : (_currentIndex + 1) / _cards.length,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '已掌握 $mastered',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _cards.isEmpty
                  ? const Center(child: Text('暂无卡片'))
                  : PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                          _showAnswer = false;
                        });
                        unawaited(_saveProgress());
                      },
                      itemCount: _cards.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                          child: _StudyCard(
                            card: _cards[index],
                            showAnswer: _showAnswer,
                            onTap: () =>
                                setState(() => _showAnswer = !_showAnswer),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _goPrevious,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _cards.isEmpty
                          ? null
                          : () => setState(() => _showAnswer = !_showAnswer),
                      icon: Icon(
                        _showAnswer
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      label: Text(_showAnswer ? '隐藏答案' : '查看答案'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _cards.isEmpty
                        ? null
                        : () => _speakCurrent(includeAnswer: _showAnswer),
                    icon: Icon(
                      _isSpeaking ? Icons.pause : Icons.volume_up_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _goNext,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cards.isEmpty ? null : _markMastered,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('标记已掌握并下一张'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyCard extends StatelessWidget {
  final Flashcard card;
  final bool showAnswer;
  final VoidCallback onTap;

  const _StudyCard({
    required this.card,
    required this.showAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: const Color(0xFFE7DEC9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    card.cardType.label,
                    style: const TextStyle(
                      color: Color(0xFF8A5C00),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  '点击翻面',
                  style: TextStyle(
                    color: Colors.black38,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  showAnswer
                      ? (card.back.isEmpty ? card.answer : card.back)
                      : card.front,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 25,
                    height: 1.55,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (showAnswer) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '答案：${card.answer}\n原文：${card.sourceQuote}',
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
