import 'package:flutter/material.dart';
import 'dart:async';

/// 商城分区组件 - 抖音商城风格
class ShopMallListView extends StatefulWidget {
  const ShopMallListView({super.key});

  @override
  State<ShopMallListView> createState() => _ShopMallListViewState();
}

class _ShopMallListViewState extends State<ShopMallListView> {
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  // 模拟Banner数据
  final List<Map<String, dynamic>> _banners = [
    {
      'gradient': [const Color(0xFFE74C3C), const Color(0xFFC0392B)],
      'title': '⛩️ 开光法器',
      'subtitle': '殊胜加持·限时特惠',
    },
    {
      'gradient': [const Color(0xFFD4AF37), const Color(0xFFC5A028)],
      'title': '🙏 供养功德',
      'subtitle': '随喜供养·福慧双修',
    },
    {
      'gradient': [const Color(0xFF667eea), const Color(0xFF764ba2)],
      'title': '📿 念珠法物',
      'subtitle': '精选材质·如法制作',
    },
  ];

  // 模拟分类数据
  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.auto_awesome, 'name': '功德法器', 'color': const Color(0xFFE74C3C)},
    {'icon': Icons.temple_buddhist, 'name': '佛像供具', 'color': const Color(0xFFD4AF37)},
    {'icon': Icons.menu_book, 'name': '经书法物', 'color': const Color(0xFF667eea)},
    {'icon': Icons.card_giftcard, 'name': '禅意礼品', 'color': const Color(0xFF11998e)},
    {'icon': Icons.spa, 'name': '香品香具', 'color': const Color(0xFF8E44AD)},
    {'icon': Icons.self_improvement, 'name': '禅修用品', 'color': const Color(0xFFE67E22)},
    {'icon': Icons.local_florist, 'name': '供花供果', 'color': const Color(0xFFE91E63)},
    {'icon': Icons.more_horiz, 'name': '更多分类', 'color': Colors.grey},
  ];

  // 模拟商品数据
  final List<Map<String, dynamic>> _products = [
    {
      'name': '天然小叶紫檀念珠108颗',
      'price': 298.00,
      'originalPrice': 598.00,
      'sales': 2341,
      'rating': 4.9,
      'tag': '热卖',
      'gradient': [const Color(0xFF8B4513), const Color(0xFFA0522D)],
    },
    {
      'name': '纯铜鎏金释迦牟尼佛像',
      'price': 1680.00,
      'originalPrice': 2380.00,
      'sales': 856,
      'rating': 5.0,
      'tag': '精品',
      'gradient': [const Color(0xFFD4AF37), const Color(0xFFB8860B)],
    },
    {
      'name': '老山檀香线香 天然香料',
      'price': 68.00,
      'originalPrice': 128.00,
      'sales': 5621,
      'rating': 4.8,
      'tag': '爆款',
      'gradient': [const Color(0xFF8B7355), const Color(0xFFCD853F)],
    },
    {
      'name': '手工打造铜磬 清脆悦耳',
      'price': 388.00,
      'originalPrice': 688.00,
      'sales': 1234,
      'rating': 4.9,
      'tag': '新品',
      'gradient': [const Color(0xFFB87333), const Color(0xFFCD7F32)],
    },
    {
      'name': '纯手工刺绣禅修蒲团',
      'price': 168.00,
      'originalPrice': 268.00,
      'sales': 3456,
      'rating': 4.7,
      'tag': '热卖',
      'gradient': [const Color(0xFF4A4A4A), const Color(0xFF696969)],
    },
    {
      'name': '黄铜供水杯七只套装',
      'price': 128.00,
      'originalPrice': 198.00,
      'sales': 2789,
      'rating': 4.8,
      'tag': '',
      'gradient': [const Color(0xFFDAA520), const Color(0xFFFFD700)],
    },
    {
      'name': '精装大字《金刚经》',
      'price': 38.00,
      'originalPrice': 68.00,
      'sales': 8976,
      'rating': 4.9,
      'tag': '热卖',
      'gradient': [const Color(0xFF8B0000), const Color(0xFFB22222)],
    },
    {
      'name': '莲花酥油灯座 纯铜制作',
      'price': 58.00,
      'originalPrice': 98.00,
      'sales': 4532,
      'rating': 4.8,
      'tag': '',
      'gradient': [const Color(0xFFFF6B6B), const Color(0xFFFFE66D)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _startBannerAutoPlay();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoPlay() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients) {
        final nextPage = (_currentBannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      child: Stack(
        children: [
          // 内容区域 (底层)
          SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                // 顶部间距（为固定搜索栏和标签栏留空间）
                // TabBar (约50) + 搜索栏 (约40) + 间距
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),

                // 用户功能菜单 (订单、地址、收藏)
                SliverToBoxAdapter(
                  child: _buildUserMenuSection(),
                ),

                // Banner轮播
                SliverToBoxAdapter(
                  child: _buildBannerSection(),
                ),

                // 分类入口
                SliverToBoxAdapter(
                  child: _buildCategorySection(),
                ),

                // 热门推荐标题
                SliverToBoxAdapter(
                  child: _buildSectionTitle('🔥 热门推荐'),
                ),

                // 商品网格
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.58, // 进一步调整比例以修复底部溢出
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildProductCard(_products[index]),
                      childCount: _products.length,
                    ),
                  ),
                ),

                // 底部间距
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),

          // 固定搜索栏 (顶层)
          Positioned(
            top: 54, // 下移以避开顶部 TabBar
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 0), 
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF121212),
                    const Color(0xFF121212).withOpacity(0.95),
                    const Color(0xFF121212).withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
              child: _buildSearchBar(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建用户功能菜单
  Widget _buildUserMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildUserMenuItem(Icons.inventory_2_outlined, '我的订单', Colors.blue),
          _buildUserMenuItem(Icons.location_on_outlined, '收货地址', Colors.orange),
          _buildUserMenuItem(Icons.star_outline, '我的收藏', Colors.yellow),
        ],
      ),
    );
  }

  Widget _buildUserMenuItem(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label功能开发中...')),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 减小高度
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A), // 不透明背景
        borderRadius: BorderRadius.circular(20), // 增加圆角
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          const Text(
            '搜索商品、品牌...',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '搜索',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建Banner轮播区域
  Widget _buildBannerSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      height: 160,
      child: Stack(
        children: [
          PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) {
              setState(() => _currentBannerIndex = index);
            },
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: banner['gradient'] as List<Color>,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    // 装饰图案
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.local_mall_outlined,
                        size: 140,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    // Banner内容
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            banner['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            banner['subtitle'] as String,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '立即购买',
                              style: TextStyle(
                                color: (banner['gradient'] as List<Color>)[0],
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // 指示器
          Positioned(
            bottom: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(_banners.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(left: 6),
                  width: _currentBannerIndex == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentBannerIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分类入口区域
  Widget _buildCategorySection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '分类导航',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${category['name']} 分类开发中...'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: category['color'] as Color,
                      ),
                    );
                  },
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: (category['color'] as Color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (category['color'] as Color).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            category['icon'] as IconData,
                            color: category['color'] as Color,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category['name'] as String,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建区块标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('查看更多功能开发中...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Row(
              children: [
                Text(
                  '查看更多',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建商品卡片
  Widget _buildProductCard(Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('查看商品: ${product['name']}'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // 深色卡片背景
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品图片区域
            Stack(
              children: [
                Container(
                  height: 140, // 稍微减小高度，留更多空间给文字
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: product['gradient'] as List<Color>,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 48,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
                // 标签 (左上角)
                if ((product['tag'] as String).isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE74C3C), // 红色标签
                        borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
                      ),
                      child: Text(
                        product['tag'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // 商品信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 商品名称
                    Text(
                      product['name'] as String,
                      style: const TextStyle(
                        color: Colors.white, // 白色文字
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // 价格与购物车
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 价格区域
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 crossAxisAlignment: CrossAxisAlignment.baseline,
                                 textBaseline: TextBaseline.alphabetic,
                                 children: [
                                   const Text(
                                     '¥',
                                     style: TextStyle(
                                       color: Color(0xFFFF4D4F), // 价格红
                                       fontSize: 12,
                                       fontWeight: FontWeight.bold,
                                     ),
                                   ),
                                   Flexible(
                                     child: Text(
                                       '${(product['price'] as double).toStringAsFixed(0)}',
                                       style: const TextStyle(
                                         color: Color(0xFFFF4D4F),
                                         fontSize: 18,
                                         fontWeight: FontWeight.bold,
                                       ),
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                   ),
                                 ],
                               ),
                               const SizedBox(height: 2),
                               Text(
                                 '已售${product['sales']}',
                                 style: TextStyle(
                                   color: Colors.white.withOpacity(0.4),
                                   fontSize: 10,
                                 ),
                               ),
                             ],
                           ),
                         ),
                         
                        // 购物车按钮
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart,
                            size: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
