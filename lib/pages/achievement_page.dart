import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/settings_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';

/// 成就勋章页
///
/// **对应需求模块 5：**
/// - 勋章墙按「成长 / 习惯 / 效率 / 知识」四类分组
/// - 未解锁的勋章灰显
/// - 解锁后亮起并给予小奖励
class AchievementPage extends ConsumerStatefulWidget {
  const AchievementPage({super.key});

  @override
  ConsumerState<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends ConsumerState<AchievementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AchievementCategory.values.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(unlockedAchievementCountProvider);
    final total = ref.watch(totalAchievementCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('成就勋章'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // 总进度
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.spaceLg,
                  vertical: AppSizes.spaceSm,
                ),
                child: Row(
                  children: [
                    const Text('🏅', style: TextStyle(fontSize: 20)),
                    SizedBox(width: AppSizes.spaceSm),
                    Text(
                      '已解锁 $unlocked / $total',
                      style: TextStyle(
                        fontSize: AppSizes.fontBody,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: AppSizes.spaceMd),
                    Expanded(
                      child: AppProgressBar(
                        value: total == 0 ? 0 : unlocked / total,
                        color: AppColors.secondary,
                        height: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // 分类 Tab
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: AppColors.textHint,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: TextStyle(
                  fontSize: AppSizes.fontBody,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: AppSizes.fontBody,
                  fontWeight: FontWeight.w600,
                ),
                tabs: AchievementCategory.values
                    .map((c) => Tab(
                          child: Row(
                            children: [
                              Text(c.emoji, style: const TextStyle(fontSize: 18)),
                              SizedBox(width: AppSizes.spaceXs),
                              Text(c.label),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: AchievementCategory.values
            .map((c) => _buildCategoryGrid(c))
            .toList(),
      ),
    );
  }

  /// 某个分类的勋章网格
  Widget _buildCategoryGrid(AchievementCategory category) {
    final views = ref.watch(achievementsByCategoryProvider(category));

    if (views.isEmpty) {
      return const EmptyPlaceholder(
        emoji: '🏅',
        text: '这个分类还没有勋章',
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(AppSizes.spaceLg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSizes.spaceLg,
        crossAxisSpacing: AppSizes.spaceLg,
        childAspectRatio: 0.85,
      ),
      itemCount: views.length,
      itemBuilder: (context, i) => _buildBadgeCard(views[i]),
    );
  }

  /// 单个勋章卡
  Widget _buildBadgeCard(AchievementView view) {
    final unlocked = view.isUnlocked;

    return AppCard(
      padding: EdgeInsets.all(AppSizes.spaceLg),
      onTap: () => _showBadgeDetail(view),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ---------- 勋章图标（未解锁灰显） ----------
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 已解锁：金色渐变；未解锁：灰色
              gradient: unlocked
                  ? const LinearGradient(
                      colors: [Color(0xFFFFE08A), Color(0xFFF5B942)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: unlocked ? null : const Color(0xFFE0E0E0),
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              view.def.iconEmoji,
              style: TextStyle(
                fontSize: 38,
                // 未解锁降低亮度
                color: unlocked ? null : Colors.grey,
              ),
            ),
          ),
          SizedBox(height: AppSizes.spaceMd),

          // ---------- 名称 ----------
          Text(
            view.def.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppSizes.fontBody,
              fontWeight: FontWeight.w800,
              color: unlocked ? AppColors.textPrimary : AppColors.textHint,
            ),
          ),
          SizedBox(height: AppSizes.spaceXs),

          // ---------- 描述 ----------
          Text(
            view.def.description,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppSizes.fontCaption,
              color: unlocked ? AppColors.textSecondary : AppColors.textHint,
            ),
          ),
          SizedBox(height: AppSizes.spaceSm),

          // ---------- 进度 / 已解锁 ----------
          if (unlocked)
            TagChip(
              text: '已解锁',
              color: AppColors.success.withValues(alpha: 0.2),
              textColor: AppColors.success,
              fontSize: AppSizes.fontTiny,
            )
          else
            Column(
              children: [
                AppProgressBar(
                  value: view.ratio,
                  height: 8,
                  color: AppColors.textHint,
                ),
                SizedBox(height: AppSizes.spaceXs),
                Text(
                  view.progressLabel,
                  style: TextStyle(
                    fontSize: AppSizes.fontTiny,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 勋章详情弹窗
  void _showBadgeDetail(AchievementView view) {
    final unlocked = view.isUnlocked;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: EdgeInsets.all(AppSizes.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 大图标
              Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unlocked
                      ? const LinearGradient(
                          colors: [Color(0xFFFFE08A), Color(0xFFF5B942)],
                        )
                      : null,
                  color: unlocked ? null : const Color(0xFFE0E0E0),
                ),
                child: Text(
                  view.def.iconEmoji,
                  style: const TextStyle(fontSize: 50),
                ),
              ),
              SizedBox(height: AppSizes.spaceLg),
              Text(
                view.def.name,
                style: TextStyle(
                  fontSize: AppSizes.fontTitle,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: AppSizes.spaceSm),
              Text(
                view.def.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizes.fontBody,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppSizes.spaceLg),

              // 达成条件
              Container(
                padding: EdgeInsets.all(AppSizes.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Column(
                  children: [
                    Text(
                      '达成条件：${view.progressLabel}',
                      style: TextStyle(
                        fontSize: AppSizes.fontLabel,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSizes.spaceXs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('解锁奖励：',
                            style: TextStyle(
                              fontSize: AppSizes.fontCaption,
                              color: AppColors.textSecondary,
                            )),
                        CoinLabel(
                          type: view.def.rewardType,
                          amount: view.def.rewardValue,
                          fontSize: AppSizes.fontCaption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 解锁时间
              if (unlocked && view.progress.unlockedAt != null) ...[
                SizedBox(height: AppSizes.spaceMd),
                Text(
                  '解锁于 ${view.progress.unlockedAt!.year}年'
                  '${view.progress.unlockedAt!.month}月'
                  '${view.progress.unlockedAt!.day}日',
                  style: TextStyle(
                    fontSize: AppSizes.fontCaption,
                    color: AppColors.textHint,
                  ),
                ),
              ],

              SizedBox(height: AppSizes.spaceXl),
              BouncyButton(
                onPressed: () => Navigator.pop(ctx),
                width: 160,
                child: const Text('知道啦'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
