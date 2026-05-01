import 'package:flutter/material.dart';
import 'package:global_dharma_sharing/screens/search_screen.dart';

/// 法流顶部标签栏（抖音风格）
class FeedTabBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChanged;

  const FeedTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 左侧占位，保持中间标签居中 (减少宽度以适应更多标签)
          const SizedBox(width: 40),

          // 中间标签栏
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTab('法流', 0),
                  const SizedBox(width: 12),
                  _buildTab('热门', 1),
                  const SizedBox(width: 12),
                  _buildTab('感应', 2),
                  const SizedBox(width: 12),
                  _buildTab('发愿', 3),
                ],
              ),
            ),
          ),

          // 右侧搜索图标
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTabChanged(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: isSelected ? 17 : 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              shadows: const [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2.0,
                  color: Colors.black26,
                ),
              ],
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 20,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}
