import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'globe_home_screen.dart';
import 'leaderboard_screen.dart';
import 'meditation_room_screen.dart';
import 'my_profile_screen.dart';
import 'video_feed_screen.dart';
import '../core/design_system/app_theme.dart';
import '../widgets/space_background.dart';
import '../providers/video_feed_visibility_notifier.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isGlobeReady = false;
  
  // 追踪哪些页面已被激活
  final List<bool> _activatedScreens = [true, false, false, false];
  
  // 用于通知各主页面的可见性变化
  final GlobalKey<MeditationRoomScreenState> _meditationKey = GlobalKey();
  final GlobalKey<GlobeHomeScreenState> _globeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 立即加载，由 GlobeHomeScreen 内部控制延迟
    _isGlobeReady = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初始化时设置视频流页面可见性（默认 index=0 不可见）
    _updateVideoFeedVisibility();
  }

  /// 更新视频流页面可见性状态
  void _updateVideoFeedVisibility() {
    // 使用 context.read 避免重复监听
    final notifier = context.read<VideoFeedVisibilityNotifier>();
    notifier.setVisible(_currentIndex == 1 && _activatedScreens[1]); // 仅在激活且选中的情况下可见
  }
  
  /// 更新禅室页面可见性状态
  void _updateMeditationRoomVisibility() {
    final isZenRoomVisible = _currentIndex == 2 && _activatedScreens[2];
    // 使用 GlobalKey 通知禅室页面可见性变化
    _meditationKey.currentState?.setVisible(isZenRoomVisible);
  }
  
  /// 更新地球页面可见性状态
  void _updateGlobeVisibility() {
    final isGlobeVisible = _currentIndex == 0;
    _globeKey.currentState?.setVisible(isGlobeVisible);
  }

  // 保持所有页面实例，按需延迟加载
  List<Widget> get _screens {
    final screens = <Widget>[];
    
    // 0: 首页 (地球)
    screens.add(_isGlobeReady
        ? GlobeHomeScreen(key: _globeKey)
        : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在加载地球组件...')],
            ),
          ));
          
    // 1: 法流 (视频)
    screens.add(_activatedScreens[1] 
        ? const VideoFeedScreen() 
        : const Center(child: CircularProgressIndicator()));
        
    // 2: 禅室 (佛像3D)
    screens.add(_activatedScreens[2] 
        ? MeditationRoomScreen(key: _meditationKey) 
        : const Center(child: CircularProgressIndicator()));
        
    // 3: 我的
    screens.add(_activatedScreens[3] 
        ? const MyProfileScreen() 
        : const Center(child: CircularProgressIndicator()));
        
    return screens;
  }

  @override
  Widget build(BuildContext context) {
    return SpaceBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: AppTheme.primaryColor.withOpacity(0.3),
              iconTheme: WidgetStateProperty.all(
                const IconThemeData(color: Colors.white),
              ),
              labelTextStyle: WidgetStateProperty.all(
                const TextStyle(color: Colors.white),
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF), // Glass effect
              border: const Border(top: BorderSide(color: Color(0x26FFFFFF))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                  // 标记页面为激活状态
                  if (!_activatedScreens[index]) {
                    _activatedScreens[index] = true;
                  }
                });
                _updateVideoFeedVisibility();
                _updateMeditationRoomVisibility();  // 通知禅室页面可见性变化
                _updateGlobeVisibility(); // 通知地球页面可见性变化
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 70,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.public_outlined), 
                  selectedIcon: Icon(Icons.public),
                  label: '首页'
                ),
                NavigationDestination(
                  icon: Icon(Icons.video_library_outlined), 
                  selectedIcon: Icon(Icons.video_library),
                  label: '法流'
                ),
                NavigationDestination(
                  icon: Icon(Icons.self_improvement_outlined), 
                  selectedIcon: Icon(Icons.self_improvement),
                  label: '禅室'
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline), 
                  selectedIcon: Icon(Icons.person),
                  label: '我的'
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
