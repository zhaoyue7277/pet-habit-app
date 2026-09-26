import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../routes/app_router.dart';
import '../providers/core_providers.dart';
import '../providers/habit_providers.dart';
import '../providers/pet_providers.dart';
import '../providers/task_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/task_card.dart';
import 'learning_report_page.dart';
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

  /// v1.3.0：点击宠物后的临时回话（覆盖气泡里的闲时台词）
  String? _tapDialogue;
  Timer? _tapDialogueTimer;

  /// 点击宠物：互动动画 + 换一句「点击专用台词」
  void _onPetTapped() {
    _triggerRandomAnimation();

    final live = ref.read(petLiveStateProvider);
    final text = ref.read(databaseProvider).pickDialogue(
          trigger: PetDialogueTrigger.tapPet,
          moodState: live?.moodState,
          name: ref.read(activeChildProvider)?.name ?? '小朋友',
        );

    _tapDialogueTimer?.cancel();
    setState(() => _tapDialogue = text);
    _tapDialogueTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _tapDialogue = null);
    });
  }

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
  void dispose() {
    _tapDialogueTimer?.cancel();
    super.dispose();
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

            SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceLg)),

            // ---------- 宠物区 + 今日统计 ----------
            SliverToBoxAdapter(child: _buildPetSection()),

            SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceLg)),

            // ---------- 宠物对话气泡 ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.spaceLg,
                ),
                child: PetDialogueBubble(
                  text: _tapDialogue ??
                      ref.watch(petLiveStateProvider)?.dialogue ??
                      '今天也要加油哦～',
                ),
              ),
            ),

            // ---------- v1.4.0：学习报表入口提醒 ----------
            //
            // 【为什么用「提醒条」而不是自动弹窗？】
            // 用户选的是「手动查看 + 入口提醒」。自动弹窗有两个问题：
            //   1. 打断操作（孩子刚打开 App 想打卡，先被糊一脸报表）；
            //   2. 很快就变成「每次都弹 → 直接点掉」的噪音。
            // 提醒条则是「在那里，但不烦你」，孩子想看就点。
            //
            // 【什么时候才显示？】
            // 只在晚上 18 点后（一天快结束，看日报才有意义），
            // 或者有被驳回的打卡时（这件事需要立刻知道）。
            const SliverToBoxAdapter(child: _ReportReminderBar()),

            SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceXl)),

            // ---------- 待办任务标题 ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
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
                    SizedBox(width: AppSizes.spaceSm),
                    Text(
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
                      child: Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.primary,
                        size: AppSizes.iconMd,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(child: SizedBox(height: AppSizes.spaceMd)),

            // ---------- 任务列表（按科目分组） ----------
            ..._buildTaskGroups(),

            // 底部留白，避免被导航栏遮挡
            SliverToBoxAdapter(
              child: SizedBox(height: AppSizes.bottomNavHeight + 40),
            ),
          ],
        ),
      ),
    );
  }

  /// 宠物形象区（左侧宠物 + 右侧统计卡）
  ///
  /// **响应式改造（v1.2.3）**：宠物卡宽度不再硬编码 150，
  /// 而是按屏宽比例计算（约 36%，夹在 120~150 之间），
  /// 保证极窄屏（320dp）下右侧统计卡仍有足够空间，不溢出。
  Widget _buildPetSection() {
    final live = ref.watch(petLiveStateProvider);
    final child = ref.watch(activeChildProvider);

    final screenW = MediaQuery.of(context).size.width;
    final petCardW = (screenW * 0.36).clamp(112.0, 150.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- 左侧：宠物舞台（v2：渐变天幕卡，替代裸放宠物） ----------
          SizedBox(
            width: petCardW,
            child: Container(
              padding: EdgeInsets.symmetric(
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
                      SizedBox(width: AppSizes.spaceSm),
                      const Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      SizedBox(width: AppSizes.spaceXs),
                      Flexible(
                        child: Text(
                          '${live?.mood ?? 0}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppSizes.fontBody,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                    ],
                ),
                SizedBox(height: AppSizes.spaceXs),

                // 宠物形象（点击触发互动动画）
                GestureDetector(
                  onTap: _onPetTapped,
                  child: PetAvatar(
                    pet: live?.pet,
                    size: AppSizes.petHomeSize,
                    moodState: live?.moodState ?? PetMoodState.normal,
                    isJumping: _jumping,
                    isSpinning: _spinning,
                    // 3D 路径的点击由 WebView 内部判定后回传
                    onTap: _onPetTapped,
                  ),
                ),

                // 经验条（v2：矢量图标 + 暖黄进度条）
                SizedBox(height: AppSizes.spaceSm),
                AppProgressBar(
                  value: live?.expProgress ?? 0,
                  trailing: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppColors.accentDark,
                  ),
                ),
                SizedBox(height: AppSizes.spaceXs),

                // 等级与状态数值
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lv.${live?.pet.level ?? 1}',
                      style: TextStyle(
                        fontSize: AppSizes.fontCaption,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                    SizedBox(width: AppSizes.spaceSm),
                    Text(
                      '🍚${live?.satiety ?? 0}',
                      style: TextStyle(
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
          ),

          SizedBox(width: AppSizes.spaceMd),

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
          child: Padding(
            // 底部额外留白：避开中央 FAB 与底部导航栏，避免视觉重叠
            padding: EdgeInsets.only(
              bottom: AppSizes.bottomNavHeight + 56,
            ),
            child: EmptyPlaceholder(
              emoji: '🎉',
              text: '今天还没有任务哦',
              hint: '点右上角「+」添加任务吧',
              action: BouncyButton(
                onPressed: _openTaskCreate,
                width: 200,
                child: const Text('添加任务'),
              ),
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
                padding: EdgeInsets.only(left: AppSizes.spaceLg),
                child: SubjectTag(subject: entry.key),
              ),
              SizedBox(height: AppSizes.spaceSm),

              // 该科目下的任务
              ...entry.value.map(
                (task) => Padding(
                  padding: EdgeInsets.fromLTRB(
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
          style: TextStyle(
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
        margin: EdgeInsets.all(AppSizes.spaceLg),
        padding: EdgeInsets.all(AppSizes.spaceXl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '切换小朋友',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontHeadline,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.spaceXl),

            // 孩子列表
            ...children.map((c) {
              final isActive = c.id == active?.id;
              return Padding(
                padding: EdgeInsets.only(bottom: AppSizes.spaceMd),
                child: GestureDetector(
                  onTap: () async {
                    await ref.read(childControllerProvider).switchChild(c.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: EdgeInsets.all(AppSizes.spaceLg),
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
                        SizedBox(width: AppSizes.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: TextStyle(
                                  fontSize: AppSizes.fontBody,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '💛${c.wishCoin}  🪙${c.petCoin}',
                                style: TextStyle(
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
                style: TextStyle(fontSize: AppSizes.fontBody),
                decoration: const InputDecoration(hintText: '输入名字'),
              ),
              SizedBox(height: AppSizes.spaceLg),
              // 头像选择
              Wrap(
                spacing: AppSizes.spaceSm,
                children: List.generate(Child.avatarEmojis.length, (i) {
                  final selected = i == avatarIndex;
                  return GestureDetector(
                    onTap: () => setDialogState(() => avatarIndex = i),
                    child: Container(
                      padding: EdgeInsets.all(AppSizes.spaceSm),
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

/// 学习报表入口提醒条（v1.4.0）
///
/// **显示条件（三者满足任一）：**
/// 1. 有被驳回的打卡 → 必须让孩子立刻知道（绿色→橙色提醒）；
/// 2. 晚上 18:00 之后 → 一天快结束，看日报最有意义；
/// 3. 暂无（白天且无驳回）→ 完全不显示。
///
/// **为什么是 18 点？** 太早（比如中午）看日报，数据还是半截的，
/// 容易让孩子觉得「我做得很少」而沮丧；18 点后基本一天的活动都
/// 结束了，这时候的总结才是完整的、公平的。
class _ReportReminderBar extends ConsumerWidget {
  const _ReportReminderBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rejected = ref.watch(rejectedCheckInsTodayProvider);
    final pendingCount = ref.watch(pendingCheckInCountProvider);
    final isEvening = DateTime.now().hour >= 18;

    // 三者都不满足 → 不占位
    if (rejected.isEmpty && !isEvening && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    // ---------- 文案与配色按优先级决定 ----------
    final String emoji;
    final String text;
    final Color bg;
    final Color fg;

    if (rejected.isNotEmpty) {
      emoji = '↩️';
      text = '有 ${rejected.length} 个打卡被退回了，补做一遍就能重交～';
      bg = AppColors.warning.withValues(alpha: 0.16);
      fg = AppColors.secondaryDark;
    } else if (pendingCount > 0) {
      emoji = '⏳';
      text = '$pendingCount 个打卡等着爸爸妈妈确认…';
      bg = AppColors.primary.withValues(alpha: 0.12);
      fg = AppColors.primaryDark;
    } else {
      emoji = '📖';
      text = '今天过得怎么样？看看宠物写的日报吧～';
      bg = AppColors.info.withValues(alpha: 0.14);
      fg = AppColors.primaryDark;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.spaceLg,
        AppSizes.spaceLg,
        AppSizes.spaceLg,
        0,
      ),
      child: GestureDetector(
        onTap: () => AppNavigator.push(
          context,
          const LearningReportPage(),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.spaceMd,
            vertical: AppSizes.spaceSm,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: AppScale.s(18))),
              SizedBox(width: AppSizes.spaceSm),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: AppSizes.fontCaption,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: AppScale.s(20),
                color: fg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
