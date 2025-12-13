import 'package:flutter/material.dart';
import 'widgets/feed_tab_bar.dart';
import 'widgets/feed_post_list_view.dart';
import 'widgets/hot_feed_list_view.dart';
import 'video_feed_view.dart';

/// 法流标签切换主视图
/// 包含法流、热门、感应、发愿四个标签页
class FeedTabView extends StatefulWidget {
  const FeedTabView({super.key});

  @override
  State<FeedTabView> createState() => _FeedTabViewState();
}

class _FeedTabViewState extends State<FeedTabView> {
  int _selectedTabIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() => _selectedTabIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _selectedTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 内容区域 - 全屏显示
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: const [
                // 法流 - 原有的垂直滚动视频/文本流
                VideoFeedView(),
                
                // 热门 - 只显示有点赞量的内容
                HotFeedListView(),
                
                // 感应 - 朋友圈式列表
                FeedPostListView(tag: 'ganying'),
                
                // 发愿 - 朋友圈式列表
                FeedPostListView(tag: 'fayuan'),
              ],
            ),
          ),

          // 顶部标签栏 - 浮动在上方
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.transparent,
                child: FeedTabBar(
                  selectedIndex: _selectedTabIndex,
                  onTabChanged: _onTabChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
