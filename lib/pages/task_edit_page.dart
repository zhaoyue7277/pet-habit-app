import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/task_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';

/// 新建 / 编辑任务页
///
/// **对应截图 2「新建任务」：**
/// - 任务标题 + 「✨ 分解任务」按钮
/// - 描述（可选）+ 图片按钮
/// - 科目：语文 / 数学 / 英语 / +
/// - 优先级：I 必须做 / II 应该做 / III 可以做
/// - 难度：简单 / 中等 / 困难
/// - 日期：今天 / 明天 / 其他
/// - 预估完成时间（不确定）
/// - 重复（无）
/// - 自定义奖励开关
/// - **【新增】** 是否需要番茄钟（计时类 / 检查类）
class TaskEditPage extends ConsumerStatefulWidget {
  const TaskEditPage({super.key, this.task, this.parentTaskId});

  /// 为空表示新建
  final Task? task;

  /// 父任务 ID（用于「分解任务」创建子任务）
  final String? parentTaskId;

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;

  // ---------- 表单字段 ----------
  String _subject = '语文';
  Priority _priority = Priority.should;
  Difficulty _difficulty = Difficulty.medium;
  DateTime? _dueDate;
  int? _estimatedMinutes;
  RepeatFrequency _repeatFrequency = RepeatFrequency.once;
  bool _needsPomodoro = false;
  RewardType _rewardType = RewardType.wishCoin;
  int _rewardValue = 15;

  /// 常用科目
  static const List<String> _defaultSubjects = ['语文', '数学', '英语'];

  /// 自定义科目
  final List<String> _customSubjects = [];

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    if (t != null) {
      _subject = t.subject;
      _priority = t.priority;
      _difficulty = t.difficulty;
      _dueDate = t.dueDate;
      _estimatedMinutes = t.estimatedMinutes;
      _repeatFrequency = t.repeatFrequency;
      _needsPomodoro = t.needsPomodoro;
      _rewardType = t.rewardType;
      _rewardValue = t.rewardValue;
      if (!_defaultSubjects.contains(t.subject)) {
        _customSubjects.add(t.subject);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? '编辑任务' : '新建任务'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.spaceLg),
            child: Center(
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceXl,
                    vertical: AppSizes.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                  ),
                  child: const Text(
                    '完成',
                    style: TextStyle(
                      fontSize: AppSizes.fontLabel,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- 标题 + 描述 ----------
            _buildTitleCard(),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 科目 ----------
            _buildSubjectRow(),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 优先级 ----------
            _buildPriorityRow(),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 难度 ----------
            _buildDifficultyRow(),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 日期 ----------
            _buildDateRow(),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 番茄钟开关（核心新增） ----------
            _buildPomodoroSwitch(),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 其他设置 ----------
            _buildOtherSettings(),

            const SizedBox(height: AppSizes.spaceXxl),
          ],
        ),
      ),
    );
  }

  /// 标题卡片
  Widget _buildTitleCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: AppSizes.fontHeadline,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: '请输入任务标题',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              // 分解任务按钮（对应截图）
              GestureDetector(
                onTap: _showDecomposeHint,
                child: const Row(
                  children: [
                    Text('✨', style: TextStyle(fontSize: 16)),
                    SizedBox(width: AppSizes.spaceXs),
                    Text(
                      '分解任务',
                      style: TextStyle(
                        fontSize: AppSizes.fontCaption,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSizes.spaceXl),
          TextField(
            controller: _descController,
            maxLines: 3,
            style: const TextStyle(fontSize: AppSizes.fontBody),
            decoration: const InputDecoration(
              hintText: '描述（可选）',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: AppSizes.spaceSm),
          // 图片按钮（占位，实际需接入 image_picker）
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _toast('图片功能需接入 image_picker，可后续启用'),
              child: const Icon(
                Icons.image_outlined,
                color: AppColors.textHint,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 科目选择行
  Widget _buildSubjectRow() {
    final subjects = [..._defaultSubjects, ..._customSubjects];

    return _buildRowLayout(
      label: '科目',
      child: Wrap(
        spacing: AppSizes.spaceSm,
        runSpacing: AppSizes.spaceSm,
        children: [
          ...subjects.map((s) => _chip(
                text: s,
                selected: _subject == s,
                onTap: () => setState(() => _subject = s),
              )),
          // 自定义科目按钮
          GestureDetector(
            onTap: _showAddSubjectDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spaceLg,
                vertical: AppSizes.spaceSm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 20, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// 优先级选择行
  Widget _buildPriorityRow() {
    return _buildRowLayout(
      label: '优先级',
      child: Wrap(
        spacing: AppSizes.spaceSm,
        runSpacing: AppSizes.spaceSm,
        children: Priority.values
            .map((p) => _chip(
                  text: '${p.romanNumeral} ${p.label}',
                  selected: _priority == p,
                  onTap: () => setState(() => _priority = p),
                ))
            .toList(),
      ),
    );
  }

  /// 难度选择行
  Widget _buildDifficultyRow() {
    return _buildRowLayout(
      label: '难度',
      child: Wrap(
        spacing: AppSizes.spaceSm,
        runSpacing: AppSizes.spaceSm,
        children: Difficulty.values
            .map((d) => _chip(
                  text: d.label,
                  selected: _difficulty == d,
                  selectedColor: switch (d) {
                    Difficulty.easy => AppColors.success,
                    Difficulty.medium => AppColors.accentDark,
                    Difficulty.hard => AppColors.error,
                  },
                  onTap: () => setState(() => _difficulty = d),
                ))
            .toList(),
      ),
    );
  }

  /// 日期选择行
  Widget _buildDateRow() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    bool isSame(DateTime? a, DateTime b) =>
        a != null && a.year == b.year && a.month == b.month && a.day == b.day;

    return _buildRowLayout(
      label: '日期',
      child: Wrap(
        spacing: AppSizes.spaceSm,
        children: [
          _chip(
            text: '今天',
            selected: isSame(_dueDate, today),
            selectedColor: AppColors.secondary,
            onTap: () => setState(() => _dueDate = today),
          ),
          _chip(
            text: '明天',
            selected: isSame(_dueDate, tomorrow),
            selectedColor: AppColors.secondary,
            onTap: () => setState(() => _dueDate = tomorrow),
          ),
          _chip(
            text: '其他',
            selected: _dueDate != null &&
                !isSame(_dueDate, today) &&
                !isSame(_dueDate, tomorrow),
            selectedColor: AppColors.secondary,
            onTap: _pickCustomDate,
          ),
        ],
      ),
    );
  }

  /// 番茄钟开关（计时类 / 检查类 的区分入口）
  Widget _buildPomodoroSwitch() {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 22, color: AppColors.primaryDark),
              const SizedBox(width: AppSizes.spaceMd),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '需要番茄钟计时',
                      style: TextStyle(
                        fontSize: AppSizes.fontBody,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSizes.spaceXs),
                    Text(
                      '做试卷、订正错题 → 开启\n书写工整、早睡早起、家务 → 关闭',
                      style: TextStyle(
                        fontSize: AppSizes.fontCaption,
                        color: AppColors.textHint,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _needsPomodoro,
                onChanged: (v) => setState(() => _needsPomodoro = v),
              ),
            ],
          ),

          // 开启时显示时长选择
          if (_needsPomodoro) ...[
            const Divider(height: AppSizes.spaceXl),
            Row(
              children: [
                const Text(
                  '预估完成时间',
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  _estimatedMinutes == null ? '不确定' : '$_estimatedMinutes 分钟',
                  style: const TextStyle(
                    fontSize: AppSizes.fontBody,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSizes.spaceXs),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint, size: 22),
              ],
            ),
            const SizedBox(height: AppSizes.spaceMd),
            // 时长快捷选择
            Wrap(
              spacing: AppSizes.spaceSm,
              runSpacing: AppSizes.spaceSm,
              children: [
                _chip(
                  text: '不确定',
                  selected: _estimatedMinutes == null,
                  onTap: () => setState(() => _estimatedMinutes = null),
                ),
                ...[15, 25, 30, 45, 60]
                    .map((m) => _chip(
                          text: '$m分钟',
                          selected: _estimatedMinutes == m,
                          onTap: () =>
                              setState(() => _estimatedMinutes = m),
                        )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 其他设置（重复、奖励）
  Widget _buildOtherSettings() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 重复
          GestureDetector(
            onTap: _pickRepeatFrequency,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spaceLg),
              child: Row(
                children: [
                  const Text(
                    '重复',
                    style: TextStyle(
                      fontSize: AppSizes.fontBody,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _repeatFrequency.label,
                    style: const TextStyle(
                      fontSize: AppSizes.fontBody,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceXs),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textHint, size: 22),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: AppSizes.spaceLg, endIndent: AppSizes.spaceLg),

          // 奖励设置
          Padding(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      '自定义奖励',
                      style: TextStyle(
                        fontSize: AppSizes.fontBody,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    // 币种切换
                    GestureDetector(
                      onTap: () => setState(() {
                        _rewardType = _rewardType == RewardType.wishCoin
                            ? RewardType.petCoin
                            : RewardType.wishCoin;
                      }),
                      child: TagChip(
                        text:
                            '${_rewardType.emoji} ${_rewardType.label}',
                        color: AppColors.surfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _rewardValue.toDouble(),
                        min: 5,
                        max: 100,
                        divisions: 19,
                        activeColor: AppColors.primary,
                        label: '$_rewardValue',
                        onChanged: (v) =>
                            setState(() => _rewardValue = v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '$_rewardValue',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: AppSizes.fontHeadline,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 行布局（左侧标签 + 右侧内容）
  Widget _buildRowLayout({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppSizes.fontBody,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// 通用选择 chip
  Widget _chip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppSizes.durationFast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceLg,
          vertical: AppSizes.spaceSm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? (selectedColor ?? AppColors.primary)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppSizes.fontLabel,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ==================== 交互 ====================

  void _showAddSubjectDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加科目'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '如：科学、美术'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              setState(() {
                if (!_customSubjects.contains(text) &&
                    !_defaultSubjects.contains(text)) {
                  _customSubjects.add(text);
                }
                _subject = text;
              });
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _pickRepeatFrequency() {
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
          children: RepeatFrequency.values.map((f) {
            final selected = _repeatFrequency == f;
            return GestureDetector(
              onTap: () {
                setState(() => _repeatFrequency = f);
                Navigator.pop(ctx);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSizes.spaceSm),
                padding: const EdgeInsets.all(AppSizes.spaceLg),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Row(
                  children: [
                    Text(
                      f.label,
                      style: const TextStyle(
                        fontSize: AppSizes.fontBody,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _showDecomposeHint() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('分解任务'),
        content: const Text(
          '把一个复杂任务拆成几个小步骤，孩子更容易完成哦。\n\n'
          '使用方式：先保存当前任务，再进入任务详情添加子任务。',
          style: TextStyle(fontSize: AppSizes.fontBody, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }

  // ==================== 保存 ====================

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _toast('请先输入任务标题');
      return;
    }

    final childId = ref.read(activeChildIdProvider);
    if (childId == null) return;

    final controller = ref.read(taskControllerProvider);

    if (_isEditing) {
      final updated = widget.task!.copyWith(
        title: title,
        description: _descController.text.trim(),
        subject: _subject,
        priority: _priority,
        difficulty: _difficulty,
        estimatedMinutes: _estimatedMinutes,
        rewardType: _rewardType,
        rewardValue: _rewardValue,
        repeatFrequency: _repeatFrequency,
        dueDate: _dueDate,
        needsPomodoro: _needsPomodoro,
      );
      await controller.updateTask(updated);
    } else {
      await controller.addTask(
        childId: childId,
        title: title,
        description: _descController.text.trim(),
        subject: _subject,
        priority: _priority,
        difficulty: _difficulty,
        estimatedMinutes: _estimatedMinutes,
        rewardType: _rewardType,
        rewardValue: _rewardValue,
        repeatFrequency: _repeatFrequency,
        dueDate: _dueDate,
        needsPomodoro: _needsPomodoro,
        parentTaskId: widget.parentTaskId,
      );
    }

    if (mounted) Navigator.pop(context);
  }
}
