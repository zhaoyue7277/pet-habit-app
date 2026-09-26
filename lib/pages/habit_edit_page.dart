import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/habit_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';

/// 创建 / 编辑习惯页
///
/// **对应截图 4「创建新习惯」：**
/// - 习惯名称 + 习惯库入口
/// - 每日打卡次数 / 打卡时段 / 打卡频率
/// - 开始时间 → 结束时间（不限 / 长期）
/// - 打卡奖励（步进器 − 10 💛 +）
/// - 打卡方式（快速打卡）
/// - 开启目标奖励开关 + 获得奖励条件 + 奖励类型 + 奖励数值 + 奖励时效
class HabitEditPage extends ConsumerStatefulWidget {
  const HabitEditPage({super.key, this.habit});

  /// 为空表示新建
  final Habit? habit;

  @override
  ConsumerState<HabitEditPage> createState() => _HabitEditPageState();
}

class _HabitEditPageState extends ConsumerState<HabitEditPage> {
  late TextEditingController _nameController;

  // ---------- 表单字段 ----------
  String _iconEmoji = '⭐';
  String? _iconAsset;
  HabitCategory _category = HabitCategory.study;
  int _dailyTargetCount = 1;
  List<TimeSlot> _timeSlots = [TimeSlot.anytime];
  HabitFrequency _frequency = HabitFrequency.daily;
  int _weeklyTargetCount = 3;
  CheckInMode _checkInMode = CheckInMode.quick;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  RewardType _checkInRewardType = RewardType.wishCoin;
  int _checkInRewardValue = 10;
  bool _enableStreakReward = true;
  int _targetStreakDays = 14;
  RewardType _targetRewardType = RewardType.wishCoin;
  int _targetRewardValue = 50;
  RewardValidity _rewardValidity = RewardValidity.once;

  bool get _isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _nameController = TextEditingController(text: h?.name ?? '');
    if (h != null) {
      _iconEmoji = h.iconEmoji;
      _iconAsset = h.iconAsset;
      _category = h.category;
      _dailyTargetCount = h.dailyTargetCount;
      _timeSlots = List<TimeSlot>.from(h.timeSlots);
      _frequency = h.frequency;
      _weeklyTargetCount = h.weeklyTargetCount;
      _checkInMode = h.checkInMode;
      _startDate = h.startDate;
      _endDate = h.endDate;
      _checkInRewardType = h.checkInRewardType;
      _checkInRewardValue = h.checkInRewardValue;
      _enableStreakReward = h.enableStreakReward;
      _targetStreakDays = h.targetStreakDays;
      _targetRewardType = h.targetRewardType;
      _targetRewardValue = h.targetRewardValue;
      _rewardValidity = h.rewardValidity;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? '编辑习惯' : '创建新习惯'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: AppSizes.spaceLg),
            child: Center(
              child: GestureDetector(
                onTap: () => _save(child),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceXl,
                    vertical: AppSizes.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                  ),
                  child: Text(
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
      body: child == null
          ? const EmptyPlaceholder(emoji: '🐣', text: '请先创建小朋友档案')
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppSizes.spaceLg),
              child: Column(
                children: [
                  // ---------- 名称 + 习惯库 ----------
                  _buildNameCard(),

                  SizedBox(height: AppSizes.spaceLg),

                  // ---------- 基础设置 ----------
                  _buildSettingsCard(),

                  SizedBox(height: AppSizes.spaceLg),

                  // ---------- 起止时间 ----------
                  _buildDateRangeCard(),

                  SizedBox(height: AppSizes.spaceLg),

                  // ---------- 打卡奖励 + 打卡方式 ----------
                  _buildRewardCard(),

                  SizedBox(height: AppSizes.spaceLg),

                  // ---------- 目标奖励 ----------
                  _buildStreakRewardCard(),

                  SizedBox(height: AppSizes.spaceXxl),
                ],
              ),
            ),
    );
  }

  /// 名称卡片（含习惯库入口）
  Widget _buildNameCard() {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              // 习惯图标
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Text(_iconEmoji, style: const TextStyle(fontSize: 26)),
              ),
              SizedBox(width: AppSizes.spaceMd),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '输入习惯名称',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              // 习惯库按钮
              GestureDetector(
                onTap: _showHabitLibrary,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceMd,
                    vertical: AppSizes.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                    border: Border.all(color: AppColors.secondary, width: 1.5),
                  ),
                  child: Text(
                    '习惯库 ›',
                    style: TextStyle(
                      fontSize: AppSizes.fontCaption,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 基础设置卡片
  Widget _buildSettingsCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _settingRow(
            '每日打卡次数',
            '$_dailyTargetCount 次',
            onTap: _pickDailyCount,
          ),
          Divider(height: 1, indent: AppSizes.spaceLg, endIndent: AppSizes.spaceLg),
          _settingRow(
            '打卡时段',
            _timeSlots.isEmpty
                ? '全天任意'
                : _timeSlots.map((e) => e.label).join('、'),
            onTap: _pickTimeSlots,
          ),
          Divider(height: 1, indent: AppSizes.spaceLg, endIndent: AppSizes.spaceLg),
          _settingRow(
            '打卡频率',
            _frequency == HabitFrequency.weekly
                ? '每周 $_weeklyTargetCount 次'
                : _frequency.label,
            onTap: _pickFrequency,
          ),
        ],
      ),
    );
  }

  /// 起止时间卡片（对应截图：紫底左右分栏）
  Widget _buildDateRangeCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Row(
        children: [
          // 开始时间
          Expanded(
            child: GestureDetector(
              onTap: () => _pickStartDate(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: AppSizes.spaceLg,
                ),
                child: Column(
                  children: [
                    Text(
                      '开始时间',
                      style: TextStyle(
                        fontSize: AppSizes.fontLabel,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSizes.spaceXs),
                    Text(
                      '${_startDate.month}月${_startDate.day}日',
                      style: TextStyle(
                        fontSize: AppSizes.fontBody,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                    SizedBox(height: AppSizes.spaceXs),
                    Text(
                      _isToday(_startDate) ? '今天' : '',
                      style: TextStyle(
                        fontSize: AppSizes.fontCaption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 中间分隔箭头
          CustomPaint(
            size: const Size(20, 90),
            painter: _ArrowSeparatorPainter(),
          ),

          // 结束时间
          Expanded(
            child: GestureDetector(
              onTap: _pickEndDate,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: AppSizes.spaceLg,
                ),
                child: Column(
                  children: [
                    Text(
                      '结束时间',
                      style: TextStyle(
                        fontSize: AppSizes.fontLabel,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSizes.spaceXs),
                    Text(
                      _endDate == null
                          ? '不限'
                          : '${_endDate!.month}月${_endDate!.day}日',
                      style: TextStyle(
                        fontSize: AppSizes.fontBody,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                    SizedBox(height: AppSizes.spaceXs),
                    Text(
                      _endDate == null ? '长期' : '',
                      style: TextStyle(
                        fontSize: AppSizes.fontCaption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 打卡奖励 + 打卡方式
  Widget _buildRewardCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.spaceLg,
              vertical: AppSizes.spaceMd,
            ),
            child: Row(
              children: [
                Text(
                  '打卡奖励',
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // 步进器 − 10 💛 +
                _stepper(
                  value: _checkInRewardValue,
                  emoji: _checkInRewardType.emoji,
                  onDecrease: () {
                    if (_checkInRewardValue > 0) {
                      setState(() => _checkInRewardValue -= 5);
                    }
                  },
                  onIncrease: () {
                    if (_checkInRewardValue < 200) {
                      setState(() => _checkInRewardValue += 5);
                    }
                  },
                  onEmojiTap: _toggleCheckInRewardType,
                ),
              ],
            ),
          ),
          Divider(height: 1, indent: AppSizes.spaceLg, endIndent: AppSizes.spaceLg),
          _settingRow('打卡方式', _checkInMode.label, onTap: _pickCheckInMode),
        ],
      ),
    );
  }

  /// 目标奖励卡片（对应截图：开启目标奖励开关等）
  Widget _buildStreakRewardCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 开关行
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.spaceLg,
              vertical: AppSizes.spaceMd,
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 20)),
                SizedBox(width: AppSizes.spaceSm),
                Text(
                  '开启目标奖励',
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _enableStreakReward,
                  onChanged: (v) => setState(() => _enableStreakReward = v),
                ),
              ],
            ),
          ),

          if (_enableStreakReward) ...[
            Divider(height: 1, indent: AppSizes.spaceLg, endIndent: AppSizes.spaceLg),
            _settingRow(
              '获得奖励条件',
              '连续打卡 $_targetStreakDays 天',
              onTap: _pickStreakDays,
            ),
            Divider(height: 1, indent: AppSizes.spaceLg, endIndent: AppSizes.spaceLg),

            // 奖励类型切换
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.spaceLg,
                vertical: AppSizes.spaceMd,
              ),
              child: Row(
                children: [
                  Text(
                    '奖励类型',
                    style: TextStyle(
                      fontSize: AppSizes.fontBody,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _segmented(
                    options: const ['心愿币', '自定义奖励'],
                    selectedIndex: _targetRewardType == RewardType.wishCoin ? 0 : 1,
                    onChanged: (i) => setState(() {
                      _targetRewardType = i == 0
                          ? RewardType.wishCoin
                          : RewardType.custom;
                    }),
                  ),
                ],
              ),
            ),

            Divider(height: 1, indent: AppSizes.spaceLg, endIndent: AppSizes.spaceLg),

            // 奖励数值
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.spaceLg,
                vertical: AppSizes.spaceMd,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '自动入账，孩子可自由兑换',
                          style: TextStyle(
                            fontSize: AppSizes.fontCaption,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _stepper(
                    value: _targetRewardValue,
                    emoji: _targetRewardType.emoji,
                    onDecrease: () {
                      if (_targetRewardValue > 0) {
                        setState(() => _targetRewardValue -= 10);
                      }
                    },
                    onIncrease: () {
                      if (_targetRewardValue < 500) {
                        setState(() => _targetRewardValue += 10);
                      }
                    },
                  ),
                ],
              ),
            ),

            Divider(height: 1, indent: AppSizes.spaceLg, endIndent: AppSizes.spaceLg),
            _settingRow('奖励时效', _rewardValidity.label, onTap: _pickRewardValidity),
          ],
        ],
      ),
    );
  }

  /// 通用设置行
  Widget _settingRow(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.spaceLg,
          vertical: AppSizes.spaceLg,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: AppSizes.fontBody,
                color: AppColors.textSecondary,
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: AppSizes.spaceXs),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 22,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 数字步进器（− N 💛 +）
  Widget _stepper({
    required int value,
    required String emoji,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
    VoidCallback? onEmojiTap,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.spaceSm,
        vertical: AppSizes.spaceXs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider, width: 1.5),
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperBtn(icon: Icons.remove_rounded, onTap: onDecrease),
          SizedBox(width: AppSizes.spaceSm),
          Text(
            '$value',
            style: TextStyle(
              fontSize: AppSizes.fontBody,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(width: AppSizes.spaceSm),
          GestureDetector(
            onTap: onEmojiTap,
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          SizedBox(width: AppSizes.spaceSm),
          _stepperBtn(icon: Icons.add_rounded, onTap: onIncrease),
        ],
      ),
    );
  }

  Widget _stepperBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }

  /// 分段选择器
  Widget _segmented({
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: AppSizes.durationFast,
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.spaceMd,
                vertical: AppSizes.spaceXs,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              ),
              child: Text(
                options[i],
                style: TextStyle(
                  fontSize: AppSizes.fontCaption,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==================== 选择器弹窗 ====================

  /// 习惯库（对应截图：四个分类 + 预置习惯网格）
  void _showHabitLibrary() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _HabitLibrarySheet(
        onSelected: (template) {
          setState(() {
            _nameController.text = template.name;
            _iconEmoji = template.iconEmoji;
            _iconAsset = template.iconAsset;
            _category = template.category;
            _dailyTargetCount = template.defaultDailyCount;
            _timeSlots = [template.defaultTimeSlot];
            _checkInRewardValue = template.defaultRewardValue;
            _targetStreakDays = template.defaultTargetStreakDays;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _pickDailyCount() {
    _showOptions(
      title: '每日打卡次数',
      options: List.generate(10, (i) => '${i + 1} 次'),
      selectedIndex: _dailyTargetCount - 1,
      onSelected: (i) => setState(() => _dailyTargetCount = i + 1),
    );
  }

  void _pickTimeSlots() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _sheetContainer(
          title: '打卡时段',
          subtitle: '可多选',
          child: Column(
            children: TimeSlot.values.map((slot) {
              final selected = _timeSlots.contains(slot);
              return GestureDetector(
                onTap: () {
                  setSheetState(() {
                    if (selected) {
                      if (_timeSlots.length > 1) _timeSlots.remove(slot);
                    } else {
                      _timeSlots.add(slot);
                    }
                  });
                  setState(() {});
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: AppSizes.spaceSm),
                  padding: EdgeInsets.all(AppSizes.spaceLg),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: selected
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(slot.emoji, style: const TextStyle(fontSize: 22)),
                      SizedBox(width: AppSizes.spaceMd),
                      Text(
                        slot.label,
                        style: TextStyle(
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
      ),
    );
  }

  void _pickFrequency() {
    _showOptions(
      title: '打卡频率',
      options: const ['每天', '每周', '自定义'],
      selectedIndex: _frequency.index,
      onSelected: (i) {
        setState(() => _frequency = HabitFrequency.values[i]);
      },
    );
  }

  void _pickCheckInMode() {
    _showOptions(
      title: '打卡方式',
      options: CheckInMode.values.map((e) => e.label).toList(),
      selectedIndex: _checkInMode.index,
      onSelected: (i) => setState(() => _checkInMode = CheckInMode.values[i]),
    );
  }

  void _pickStreakDays() {
    _showOptions(
      title: '连续打卡天数',
      options: const ['7 天', '14 天', '21 天', '30 天', '60 天', '100 天'],
      selectedIndex: const [7, 14, 21, 30, 60, 100].indexOf(_targetStreakDays),
      onSelected: (i) {
        setState(() => _targetStreakDays = [7, 14, 21, 30, 60, 100][i]);
      },
    );
  }

  void _pickRewardValidity() {
    _showOptions(
      title: '奖励时效',
      options: RewardValidity.values.map((e) => e.label).toList(),
      selectedIndex: _rewardValidity.index,
      onSelected: (i) =>
          setState(() => _rewardValidity = RewardValidity.values[i]),
    );
  }

  /// 通用选项弹窗
  void _showOptions({
    required String title,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetContainer(
        title: title,
        child: Column(
          children: List.generate(options.length, (i) {
            final selected = i == selectedIndex;
            return GestureDetector(
              onTap: () {
                onSelected(i);
                Navigator.pop(ctx);
              },
              child: Container(
                margin: EdgeInsets.only(bottom: AppSizes.spaceSm),
                padding: EdgeInsets.all(AppSizes.spaceLg),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Row(
                  children: [
                    Text(
                      options[i],
                      style: TextStyle(
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
          }),
        ),
      ),
    );
  }

  /// 底部弹窗容器
  Widget _sheetContainer({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      margin: EdgeInsets.all(AppSizes.spaceLg),
      padding: EdgeInsets.all(AppSizes.spaceXl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: AppSizes.spaceXs),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: AppSizes.fontCaption,
                color: AppColors.textHint,
              ),
            ),
          ],
          SizedBox(height: AppSizes.spaceXl),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }

  // ==================== 日期选择 ====================

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// 切换打卡奖励币种
  void _toggleCheckInRewardType() {
    setState(() {
      _checkInRewardType = _checkInRewardType == RewardType.wishCoin
          ? RewardType.petCoin
          : RewardType.wishCoin;
    });
  }

  // ==================== 保存 ====================

  Future<void> _save(Child? child) async {
    if (child == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先输入习惯名称'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      );
      return;
    }

    final controller = ref.read(habitControllerProvider);

    if (_isEditing) {
      // 更新现有习惯
      final updated = widget.habit!.copyWith(
        name: name,
        iconEmoji: _iconEmoji,
        category: _category,
        dailyTargetCount: _dailyTargetCount,
        timeSlots: _timeSlots,
        frequency: _frequency,
        weeklyTargetCount: _weeklyTargetCount,
        checkInMode: _checkInMode,
        startDate: _startDate,
        endDate: _endDate,
        checkInRewardType: _checkInRewardType,
        checkInRewardValue: _checkInRewardValue,
        enableStreakReward: _enableStreakReward,
        targetStreakDays: _targetStreakDays,
        targetRewardType: _targetRewardType,
        targetRewardValue: _targetRewardValue,
        rewardValidity: _rewardValidity,
      );
      await controller.updateHabit(updated);
    } else {
      // 新建习惯
      await controller.createHabit(
        childId: child.id,
        name: name,
        iconEmoji: _iconEmoji,
        iconAsset: _iconAsset,
        category: _category,
        dailyTargetCount: _dailyTargetCount,
        timeSlots: _timeSlots,
        frequency: _frequency,
        weeklyTargetCount: _weeklyTargetCount,
        checkInMode: _checkInMode,
        startDate: _startDate,
        endDate: _endDate,
        checkInRewardType: _checkInRewardType,
        checkInRewardValue: _checkInRewardValue,
        enableStreakReward: _enableStreakReward,
        targetStreakDays: _targetStreakDays,
        targetRewardType: _targetRewardType,
        targetRewardValue: _targetRewardValue,
        rewardValidity: _rewardValidity,
      );
    }

    if (mounted) Navigator.pop(context);
  }
}

/// 起止时间之间的箭头分隔图形
class _ArrowSeparatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.secondaryLight;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.8, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width * 0.8, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 习惯库选择弹窗
///
/// 对应截图：顶部四个分类 Tab（学习 / 健康 / 生活 / 兴趣），
/// 下方是习惯网格，每项显示图标与名称。
class _HabitLibrarySheet extends ConsumerStatefulWidget {
  const _HabitLibrarySheet({required this.onSelected});

  final ValueChanged<HabitTemplate> onSelected;

  @override
  ConsumerState<_HabitLibrarySheet> createState() => _HabitLibrarySheetState();
}

class _HabitLibrarySheetState extends ConsumerState<_HabitLibrarySheet> {
  HabitCategory _category = HabitCategory.study;

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(habitTemplatesByCategoryProvider(_category));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      margin: EdgeInsets.all(AppSizes.spaceLg),
      padding: EdgeInsets.all(AppSizes.spaceXl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '习惯库',
            style: TextStyle(
              fontSize: AppSizes.fontTitle,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSizes.spaceLg),

          // ---------- 分类 Tab ----------
          Row(
            children: HabitCategory.values.map((cat) {
              final selected = _category == cat;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceXs,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: AppSizes.durationFast,
                      padding: EdgeInsets.symmetric(
                        vertical: AppSizes.spaceSm,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.secondary
                            : AppColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusCircle),
                      ),
                      child: Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: AppSizes.fontLabel,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: AppSizes.spaceLg),

          // ---------- 习惯网格 ----------
          //
          // 【v1.4.0 修复「文字显示不全」】
          //
          // 旧写法写死 crossAxisCount: 4 + childAspectRatio: 0.8，在窄屏上
          // 每个格子只有约 68px 宽 —— 「课外阅读」这种 4 字名会被压成
          // 「课外…」。这不是字号的锅，是「格子宽度不够」。
          //
          // 三处改动：
          //   1. 列数按屏宽分档（窄屏 3 列 / 常规 4 列 / 宽屏 5 列），
          //      从根上给每个格子留出足够宽度；
          //   2. 文字允许换行到 2 行（maxLines: 2），不再 ellipsis；
          //   3. 格子高宽比放宽到 0.78（略高），给换行留出垂直空间。
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppScale.columnsFor(
                  narrowColumns: 3,
                  normalColumns: 4,
                  wideColumns: 5,
                ),
                mainAxisSpacing: AppSizes.spaceLg,
                crossAxisSpacing: AppSizes.spaceMd,
                childAspectRatio: 0.78,
              ),
              itemCount: templates.length,
              itemBuilder: (context, i) {
                final t = templates[i];
                return GestureDetector(
                  onTap: () => widget.onSelected(t),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        // 图标圈随屏幕缩放（原写死 52）
                        width: AppScale.s(52),
                        height: AppScale.s(52),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight
                              .withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          t.iconEmoji,
                          style: TextStyle(fontSize: AppScale.s(26)),
                        ),
                      ),
                      SizedBox(height: AppSizes.spaceSm),
                      // 允许换 2 行，彻底告别「课外…」
                      Flexible(
                        child: Text(
                          t.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppSizes.fontCaption,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SizedBox(height: AppSizes.spaceMd),

          // ---------- 取消按钮 ----------
          BouncyButton(
            onPressed: () => Navigator.pop(context),
            color: AppColors.secondary,
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}
