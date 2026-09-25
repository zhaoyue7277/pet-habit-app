import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../routes/app_router.dart';
import '../providers/core_providers.dart';
import '../providers/pet_providers.dart';
import '../providers/task_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/task_card.dart';
import 'pomodoro_page.dart';
import 'report_page.dart';
import 'task_edit_page.dart';

/// 首页仪表盘
///
/// 对应截图 1 的完整布局：
/// 1. 顶部问候语 + 多孩切换 + 功能图标
/// 2. 一周日期条
/// 3. 宠物形象区（等级 / 心情 / 饱食度）+ 今日统计卡
/// 4. 宠物对话气泡
/// 5. 按科目分组的待办任务列表
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _jumping = false;
  bool _spinning = false;

  /// 点击宠物触发互动动画
  void _triggerRandomAnimation() {
    if (_jumping || _spinning) return;
    if (DateTime.now().millisecond.isEven) {
      setState(() => _jumping = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _jumping = false);
      });
    } else {
      setState(() => _spinning = true);
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted) setState(() => _spinning = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);

    // 尚未建档：显示引导页
    if (child == null) {
      return _buildEmptyState();
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.read(dataRevisionProvider.notifier).bump();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ---------- 顶部问候栏 ----------
            SliverToBoxAdapter(
              child: HomeGreetingBar(
                onChildTap: _showChildSwitcher,
                onCalendarTap: _openReport,
                onPetTap: _openReport,
              ),
            ),

            // ---------- 一周日期条 ----------
            const SliverToBoxAdapter(child: WeekDateBar()),

            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceLg)),

            // ---------- 宠物区 + 今日统计 ----------
            SliverToBoxAdapter(child: _buildPetSection()),

            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceLg)),

            // ---------- 宠物对话气泡 ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spaceLg,
                ),
                child: PetDialogueBubble(
                  text: ref.watch(petLiveStateProvider)?.dialogue ??
                      '今天也要加油哦～',
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceXl)),

            // ---------- 待办任务标题 ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spaceLg,
                ),
                child: Row(
                  children: [
                    // v2：矢量图标替代 🚩 emoji
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: const Icon(
                        Icons.checklist_rounded,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    const Text(
                      '待办任务',
                      style: TextStyle(
                        fontSize: AppSizes.fontHeadline,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openTaskCreate,
                      child: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.primary,
                        size: AppSizes.iconMd,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceMd)),

            // ---------- 任务列表（按科目分组） ----------
            ..._buildTaskGroups(),

            // 底部留白，避免被导航栏遮挡
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSizes.bottomNavHeight + 40),
            ),
          ],
        ),
      ),
    );
  }

  /// 宠物形象区（左侧宠物 + 右侧统计卡）
  Widget _buildPetSection() {
    final live = ref.watch(petLiveStateProvider);
    final child = ref.watch(activeChildProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- 左侧：宠物舞台（v2：渐变天幕卡，替代裸放宠物） ----------
          Container(
            width: 150,
            padding: const EdgeInsets.symmetric(
              vertical: AppSizes.spaceMd,
              horizontal: AppSizes.spaceSm,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.skyGradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                // 心情值徽标（v2：矢量图标替代 ❤️ emoji）
                Row(
                  children: [
                    const SizedBox(width: AppSizes.spaceSm),
                    const Icon(
                      Icons.favorite_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: AppSizes.spaceXs),
                    Text(
                      '${live?.mood ?? 0}',
                      style: const TextStyle(
                        fontSize: AppSizes.fontBody,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceXs),

                // 宠物形象（点击触发互动动画）
                GestureDetector(
                  onTap: _triggerRandomAnimation,
                  child: PetAvatar(
                    pet: live?.pet,
                    size: AppSizes.petHomeSize,
                    moodState: live?.moodState ?? PetMoodState.normal,
                    isJumping: _jumping,
                    isSpinning: _spinning,
                  ),
                ),

                // 经验条（v2：矢量图标 + 暖黄进度条）
                const SizedBox(height: AppSizes.spaceSm),
                AppProgressBar(
                  value: live?.expProgress ?? 0,
                  trailing: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppColors.accentDark,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceXs),

                // 等级与状态数值
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lv.${live?.pet.level ?? 1}',
                      style: const TextStyle(
                        fontSize: AppSizes.fontCaption,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Text(
                      '🍚${live?.satiety ?? 0}',
                      style: const TextStyle(
                        fontSize: AppSizes.fontCaption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                // 未领养时提示
                if (live == null)
                  TextButton(
                    onPressed: () => _adoptPet(child!.id),
                    child: const Text('领养宠物 →'),
                  ),
              ],
            ),
          ),

          const SizedBox(width: AppSizes.spaceMd),

          // ---------- 右侧：今日统计卡 ----------
          Expanded(
            child: TodayStatsCard(onReportTap: _openReport),
          ),
        ],
      ),
    );
  }

  /// 构建按科目分组的任务列表
  List<Widget> _buildTaskGroups() {
    final grouped = ref.watch(tasksBySubjectProvider);

    if (grouped.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyPlaceholder(
            emoji: '🎉',
            text: '今天还没有任务哦',
            hint: '点击右上角 + 添加一个吧',
            action: BouncyButton(
              onPressed: _openTaskCreate,
              width: 200,
              child: const Text('添加任务'),
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 科目标签
              Padding(
                padding: const EdgeInsets.only(left: AppSizes.spaceLg),
                child: SubjectTag(subject: entry.key),
              ),
              const SizedBox(height: AppSizes.spaceSm),

              // 该科目下的任务
              ...entry.value.map(
                (task) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.spaceLg,
                    0,
                    AppSizes.spaceLg,
                    AppSizes.spaceMd,
                  ),
                  child: TaskCard(
                    task: task,
                    onTap: () => _openTaskEdit(task),
                    onComplete: _completeTask,
                    onStartTimer: () => _startPomodoro(task),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  // ==================== 交互回调 ====================

  /// 检查类任务：一键完成
  Future<void> _completeTask(Task task) async {
    final reward = await ref.read(taskControllerProvider).completeTask(task);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '太棒了！获得 ${task.rewardType.emoji} $reward',
          style: const TextStyle(
            fontSize: AppSizes.fontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }

  /// 计时类任务：进入番茄钟
  void _startPomodoro(Task task) {
    AppNavigator.push(context, PomodoroPage(task: task));
  }

  /// 打开任务编辑页
  void _openTaskEdit(Task task) {
    AppNavigator.push(context, TaskEditPage(task: task));
  }

  /// 新建任务
  void _openTaskCreate() {
    AppNavigator.push(context, const TaskEditPage());
  }

  /// 打开数据报告
  void _openReport() {
    AppNavigator.push(context, const ReportPage());
  }

  /// 多孩切换面板
  void _showChildSwitcher() {
    final children = ref.watch(allChildrenProvider);
    final active = ref.watch(activeChildProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(AppSizes.spaceLg),
        padding: const EdgeInsets.all(AppSizes.spaceXl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '切换小朋友',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontHeadline,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceXl),

            // 孩子列表
            ...children.map((c) {
              final isActive = c.id == active?.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
                child: GestureDetector(
                  onTap: () async {
                    await ref.read(childControllerProvider).switchChild(c.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.spaceLg),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: isActive
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Text(c.avatarEmoji,
                            style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: AppSizes.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontSize: AppSizes.fontBody,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '💛${c.wishCoin}  🪙${c.petCoin}',
                                style: const TextStyle(
                                  fontSize: AppSizes.fontCaption,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // 添加新孩子
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showAddChildDialog();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加小朋友'),
            ),
          ],
        ),
      ),
    );
  }

  /// 添加孩子对话框
  void _showAddChildDialog() {
    final controller = TextEditingController();
    int avatarIndex = 0;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加小朋友'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: AppSizes.fontBody),
                decoration: const InputDecoration(hintText: '输入名字'),
              ),
              const SizedBox(height: AppSizes.spaceLg),
              // 头像选择
              Wrap(
                spacing: AppSizes.spaceSm,
                children: List.generate(Child.avatarEmojis.length, (i) {
                  final selected = i == avatarIndex;
                  return GestureDetector(
                    onTap: () => setDialogState(() => avatarIndex = i),
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.spaceSm),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      child: Text(
                        Child.avatarEmojis[i],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await ref.read(childControllerProvider).createChild(
                      name: name,
                      avatarIndex: avatarIndex,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  /// 领养宠物
  Future<void> _adoptPet(String childId) async {
    await ref.read(petControllerProvider).adoptPet(
          childId: childId,
          species: PetSpecies.monster,
        );
  }

  /// 未建档时的空状态
  Widget _buildEmptyState() {
    return SafeArea(
      child: EmptyPlaceholder(
        emoji: '🐣',
        text: '欢迎来到宠物乐园！',
        hint: '先创建一个小朋友档案吧',
        action: BouncyButton(
          onPressed: _showAddChildDialog,
          width: 220,
          child: const Text('创建档案'),
        ),
      ),
    );
  }
}
