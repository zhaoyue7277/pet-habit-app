import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/home_page.dart';
import '../pages/habit_park_page.dart';
import '../pages/profile_page.dart';
import '../pages/recording_page.dart';
import '../pages/shop_page.dart';
import '../providers/core_providers.dart';
import '../providers/settings_providers.dart';
import '../routes/app_router.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';

/// 主脚手架 —— 4 个 Tab + 中间悬浮「+」按钮
///
/// **设计系统 v2 改造点：**
/// 1. 导航图标由 emoji（🏳️🎠🏪🙂，语义弱且各平台渲染不一致）替换为统一
///    圆角矢量图标：未选中 = 线框（outlined），选中 = 填充（rounded）；
/// 2. 悬浮「+」按钮由粉紫渐变改为**主色渐变**，与全局配色统一；
/// 3. 选中态新增顶部指示条 + 图标缩放，层级更清晰；
/// 4. 快捷面板图标同步矢量化为圆角图标。
class HomeScaffold extends ConsumerStatefulWidget {
  const HomeScaffold({super.key});

  @override
  ConsumerState<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends ConsumerState<HomeScaffold> {
  int _currentIndex = 0;
  Timer? _refreshTimer;

  /// 底部 Tab 配置（v2：矢量图标，未选中线框 → 选中填充）
  static const List<_TabItem> _tabs = [
    _TabItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: '首页',
    ),
    _TabItem(
      icon: Icons.park_outlined,
      activeIcon: Icons.park_rounded,
      label: '习惯乐园',
    ),
    _TabItem(
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag_rounded,
      label: '商店',
    ),
    _TabItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: '我的',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 记录打开时间（用于「多日未见」宠物台词）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsControllerProvider).touchLastOpenTime();
    });
    _startAutoRefresh();
  }

  /// 每 5 分钟自动刷新全局金币与宠物状态
  ///
  /// **注意：** 这里只是「触发 UI 重算」，
  /// 宠物饱食度 / 心情的衰减值本身是由 `petLiveStateProvider`
  /// 基于时间戳实时计算的，不依赖定时器写库。
  void _startAutoRefresh() {
    final minutes = ref.read(settingsProvider).refreshIntervalMinutes;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      if (!mounted) return;
      ref.read(dataRevisionProvider.notifier).bump();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const HabitParkPage(),
      const ShopPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      // 使用 IndexedStack 保持各 Tab 状态，避免来回切换丢失滚动位置
      // （v1.2：不再 extendBody，让 body 止于导航栏上方，避免底部内容
      // 被浮起的中央按钮遮挡 —— 旧版「添加习惯」等按钮被遮一半的问题）
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// 底部导航栏（v2：白底 + 顶部圆角 + 淡蓝柔影 + 矢量图标）
  Widget _buildBottomNav() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: AppSizes.bottomNavHeight + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // ---------- 导航栏主体 ----------
          Container(
            height: AppSizes.bottomNavHeight + bottomInset,
            padding: EdgeInsets.only(
              bottom: bottomInset,
              left: AppSizes.spaceSm,
              right: AppSizes.spaceSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface, // v2：改为纯白，替代原浅紫白
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSizes.radiusXl),
                topRight: Radius.circular(AppSizes.radiusXl),
              ),
              boxShadow: AppShadows.elevated,
            ),
            child: Row(
              children: [
                // 左侧两个 Tab
                for (int i = 0; i < 2; i++)
                  Expanded(child: _buildTabItem(i)),
                // 中间留空给悬浮按钮
                SizedBox(width: AppSizes.fabSize + AppSizes.spaceLg),
                // 右侧两个 Tab
                for (int i = 2; i < 4; i++)
                  Expanded(child: _buildTabItem(i)),
              ],
            ),
          ),

          // ---------- 中间悬浮「+」按钮 ----------
          Positioned(
            top: -AppSizes.fabSize * 0.35,
            child: _buildCenterFab(),
          ),
        ],
      ),
    );
  }

  /// 单个 Tab 项（v2：矢量图标 + 顶部选中指示条）
  Widget _buildTabItem(int index) {
    final tab = _tabs[index];
    final selected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_currentIndex == index) return;
        setState(() => _currentIndex = index);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 顶部选中指示条（v2 新增）
          AnimatedContainer(
            duration: AppSizes.durationFast,
            curve: Curves.easeOut,
            width: selected ? 22 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
            ),
          ),
          SizedBox(height: AppSizes.spaceSm),
          AnimatedScale(
            scale: selected ? 1.1 : 1.0,
            duration: AppSizes.durationFast,
            child: Icon(
              selected ? tab.activeIcon : tab.icon,
              size: AppSizes.iconMd - 2,
              color: selected ? AppColors.primary : AppColors.textHint,
            ),
          ),
          SizedBox(height: AppSizes.spaceXs),
          Text(
            tab.label,
            style: TextStyle(
              fontSize: AppSizes.fontTiny,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primaryDark : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  /// 中间的悬浮按钮 —— 弹出「开始专注 / 新建任务」选择（v2：主色渐变，替代粉紫渐变）
  Widget _buildCenterFab() {
    return GestureDetector(
      onTap: _showQuickActions,
      child: Container(
        width: AppSizes.fabSize,
        height: AppSizes.fabSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: AppColors.primaryGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: AppShadows.fab,
        ),
        child: Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: AppSizes.iconLg,
        ),
      ),
    );
  }

  /// 快捷操作面板
  void _showQuickActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: EdgeInsets.all(AppSizes.spaceLg),
        padding: EdgeInsets.all(AppSizes.spaceXl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              ),
            ),
            SizedBox(height: AppSizes.spaceXl),
            Text(
              '想做点什么呢？',
              style: TextStyle(
                fontSize: AppSizes.fontHeadline,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.spaceXl),
            // 3 列变 2×2：新增「朗读打卡」后若仍单行 4 列，
            // 在 360dp 窄屏上每格仅 ~70dp，图标+文字必然挤压换行。
            // 采用 2×2 等分网格，任意宽度下都保持舒适的点击区域。
            Row(
              children: [
                Expanded(
                  child: _quickAction(
                    icon: Icons.timer_rounded,
                    label: '开始专注',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      // 切换到首页并提示选择任务
                      setState(() => _currentIndex = 0);
                    },
                  ),
                ),
                SizedBox(width: AppSizes.spaceLg),
                Expanded(
                  child: _quickAction(
                    icon: Icons.edit_note_rounded,
                    label: '新建任务',
                    color: AppColors.secondary,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _currentIndex = 0);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.spaceLg),
            Row(
              children: [
                Expanded(
                  child: _quickAction(
                    icon: Icons.local_fire_department_rounded,
                    label: '习惯打卡',
                    color: AppColors.warning,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _currentIndex = 1);
                    },
                  ),
                ),
                SizedBox(width: AppSizes.spaceLg),
                Expanded(
                  child: _quickAction(
                    icon: Icons.mic_rounded,
                    label: '朗读打卡',
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openRecording();
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.spaceLg),
          ],
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppSizes.spaceLg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, size: 34, color: color),
            SizedBox(height: AppSizes.spaceSm),
            Text(
              label,
              style: TextStyle(
                fontSize: AppSizes.fontLabel,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 打开朗读录音页
  ///
  /// 录音是「孩子维度」的功能：没有档案时先提示去创建，
  /// 避免进入后一片空白（也避免误以为是功能坏了）。
  void _openRecording() {
    final childId = ref.read(activeChildIdProvider);
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '请先创建小朋友档案，再开始朗读打卡',
            style: TextStyle(fontSize: AppSizes.fontBody),
          ),
          backgroundColor: AppColors.info,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      );
      return;
    }
    AppNavigator.push(context, const RecordingPage());
  }
}

/// 底部 Tab 配置项（v2：使用矢量图标替代 emoji）
class _TabItem {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  /// 未选中态图标（线框）
  final IconData icon;

  /// 选中态图标（填充）
  final IconData activeIcon;

  final String label;
}

/// 供外部引用的数据库实例（避免循环依赖）
DatabaseService get db => DatabaseService.instance;
