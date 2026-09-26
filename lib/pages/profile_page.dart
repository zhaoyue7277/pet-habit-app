import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/habit_providers.dart';
import '../providers/pet_providers.dart';
import '../providers/settings_providers.dart';
import '../providers/shop_providers.dart';
import '../routes/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pin_dialog.dart';
import 'achievement_page.dart';
import 'check_in_verify_page.dart';
import 'diary_page.dart';
import 'learning_report_page.dart';
import 'pet_center_page.dart';
import 'recording_page.dart';
import 'report_page.dart';

/// 「我的」页面
///
/// 汇总：孩子信息、双币余额、宠物入口、成就勋章、数据报告、打卡日记、
/// 兑换记录、家长设置。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);

    if (child == null) {
      return const SafeArea(
        child: EmptyPlaceholder(
          emoji: '🐣',
          text: '还没有小朋友档案',
          hint: '请先在首页创建档案',
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.spaceLg,
          AppSizes.spaceLg,
          AppSizes.spaceLg,
          AppSizes.bottomNavHeight + 40,
        ),
        child: Column(
          children: [
            // ---------- 孩子信息卡 ----------
            _buildProfileCard(context, ref, child),

            SizedBox(height: AppSizes.spaceLg),

            // ---------- 功能入口网格 ----------
            _buildMenuGrid(context, ref),

            SizedBox(height: AppSizes.spaceLg),

            // ---------- 设置区 ----------
            _buildSettingsSection(context, ref),

            SizedBox(height: AppSizes.spaceXxl),
          ],
        ),
      ),
    );
  }

  /// 孩子信息卡
  Widget _buildProfileCard(BuildContext context, WidgetRef ref, Child child) {
    final live = ref.watch(petLiveStateProvider);
    final unlocked = ref.watch(unlockedAchievementCountProvider);

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              // 头像
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  child.avatarEmoji,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
              SizedBox(width: AppSizes.spaceLg),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: TextStyle(
                        fontSize: AppSizes.fontTitle,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSizes.spaceXs),
                    Text(
                      '已加入 ${DateTime.now().difference(child.createdAt).inDays} 天',
                      style: TextStyle(
                        fontSize: AppSizes.fontCaption,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),

              // 宠物小图标
              PetAvatar(
                pet: live?.pet,
                size: 56,
                moodState: live?.moodState ?? PetMoodState.normal,
              ),
            ],
          ),

          SizedBox(height: AppSizes.spaceLg),

          // ---------- 双币余额 ----------
          Container(
            padding: EdgeInsets.symmetric(
              vertical: AppSizes.spaceMd,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _balanceCell(
                    '心愿币',
                    child.wishCoin,
                    '💛',
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: _balanceCell(
                    '宠物币',
                    child.petCoin,
                    '🪙',
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: _balanceCell(
                    '勋章',
                    unlocked,
                    '🏅',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCell(String label, int value, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        SizedBox(height: AppSizes.spaceXs),
        Text(
          '$value',
          style: TextStyle(
            fontSize: AppSizes.fontHeadline,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.fontTiny,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  /// 功能入口网格
  Widget _buildMenuGrid(BuildContext context, WidgetRef ref) {
    // v1.4.0：兑换不再需要审批，角标改看「待验收打卡数」
    final pendingCheckIns = ref.watch(pendingCheckInCountProvider);

    final menus = [
      _MenuEntry(
        emoji: '🐳',
        label: '宠物中心',
        color: AppColors.primary,
        onTap: () => AppNavigator.push(context, const PetCenterPage()),
      ),
      _MenuEntry(
        emoji: '🏅',
        label: '成就勋章',
        color: AppColors.accent,
        onTap: () => AppNavigator.push(context, const AchievementPage()),
      ),
      _MenuEntry(
        emoji: '📊',
        label: '数据报告',
        color: AppColors.info,
        onTap: () => AppNavigator.push(context, const ReportPage()),
      ),
      // ---------- v1.4.0 新增：给孩子看的学习日报/周报 ----------
      _MenuEntry(
        emoji: '📖',
        label: '学习报表',
        color: AppColors.primary,
        onTap: () => AppNavigator.push(context, const LearningReportPage()),
      ),
      _MenuEntry(
        emoji: '🎤',
        label: '朗读打卡',
        color: AppColors.success,
        onTap: () => AppNavigator.push(context, const RecordingPage()),
      ),
      _MenuEntry(
        emoji: '📔',
        label: '打卡日记',
        color: AppColors.secondary,
        onTap: () => AppNavigator.push(context, const DiaryPage()),
      ),
      // ---------- v1.4.0 新增：打卡验收队列 ----------
      _MenuEntry(
        emoji: '✅',
        label: '打卡验收',
        color: AppColors.success,
        badge: pendingCheckIns,
        onTap: () => AppNavigator.push(context, const CheckInVerifyPage()),
      ),
      _MenuEntry(
        emoji: '📋',
        label: '兑换记录',
        color: AppColors.warning,
        onTap: () => _showExchangeApproval(context, ref),
      ),
      _MenuEntry(
        emoji: '⚙️',
        label: '家长设置',
        color: AppColors.textSecondary,
        onTap: () => _showParentSettings(context, ref),
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '功能',
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSizes.spaceLg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              // v1.4.0：列数按屏宽分档，避免窄屏上高度文字被挤掉
              crossAxisCount: AppScale.columnsFor(
                narrowColumns: 3,
                normalColumns: 4,
                wideColumns: 4,
              ),
              mainAxisSpacing: AppSizes.spaceLg,
              crossAxisSpacing: AppSizes.spaceMd,
              childAspectRatio: 0.95,
            ),
            itemCount: menus.length,
            itemBuilder: (context, i) => _buildMenuTile(menus[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(_MenuEntry entry) {
    return GestureDetector(
      onTap: entry.onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Text(entry.emoji, style: const TextStyle(fontSize: 28)),
              ),
              // 红点角标
              if (entry.badge > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
                    ),
                    child: Text(
                      '${entry.badge}',
                      style: TextStyle(
                        fontSize: AppSizes.fontTiny,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSizes.spaceSm),
          Text(
            entry.label,
            style: TextStyle(
              fontSize: AppSizes.fontCaption,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 设置区
  Widget _buildSettingsSection(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _settingTile(
            icon: '⏱️',
            title: '番茄钟时长',
            value: '${settings.defaultPomodoroMinutes} 分钟',
            onTap: () => _pickPomodoroMinutes(context, ref, settings),
          ),
          Divider(height: 1, indent: AppSizes.spaceLg, endIndent: AppSizes.spaceLg),
          _settingTile(
            icon: '🚪',
            title: '离开宽限时间',
            value: '${settings.allowAbandonMinutes} 分钟',
            onTap: () => _pickAbandonMinutes(context, ref, settings),
          ),
          Divider(height: 1, indent: AppSizes.spaceLg, endIndent: AppSizes.spaceLg),
          _settingTile(
            icon: '🔐',
            title: '家长密码',
            value: settings.hasSetPin ? '已设置' : '未设置',
            onTap: () => _changePin(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required String icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
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
            Text(icon, style: const TextStyle(fontSize: 22)),
            SizedBox(width: AppSizes.spaceMd),
            Text(
              title,
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
            SizedBox(width: AppSizes.spaceXs),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 22),
          ],
        ),
      ),
    );
  }

  // ==================== 交互 ====================

  Future<void> _pickPomodoroMinutes(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final options = [15, 20, 25, 30, 45, 60];
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _optionSheet(
        ctx,
        title: '番茄钟时长',
        options: options.map((e) => '$e 分钟').toList(),
        selectedIndex: options.indexOf(settings.defaultPomodoroMinutes),
        onSelected: (i) => Navigator.pop(ctx, options[i]),
      ),
    );
    if (picked != null) {
      await ref.read(settingsControllerProvider).setPomodoroMinutes(picked);
    }
  }

  Future<void> _pickAbandonMinutes(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final options = [1, 3, 5, 10, 15];
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _optionSheet(
        ctx,
        title: '离开宽限时间',
        subtitle: '切出 App 超过此时间，本次番茄钟作废',
        options: options.map((e) => '$e 分钟').toList(),
        selectedIndex: options.indexOf(settings.allowAbandonMinutes),
        onSelected: (i) => Navigator.pop(ctx, options[i]),
      ),
    );
    if (picked != null) {
      await ref.read(settingsControllerProvider).setAllowAbandonMinutes(picked);
    }
  }

  /// 修改家长密码（需先验证旧密码）
  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(shopControllerProvider);

    // 已设置过：先验证
    if (controller.hasPin) {
      final verified = await showDialog<bool>(
        context: context,
        builder: (_) => PinInputDialog(
          title: '验证家长密码',
          subtitle: '请先输入当前密码',
          onVerify: controller.verifyPin,
        ),
      );
      if (verified != true) return;
    }

    if (!context.mounted) return;

    // 设置新密码
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => PinInputDialog(
        title: '设置新密码',
        subtitle: '请输入 4 位数字密码',
        isSettingMode: true,
        onVerify: (_) => true,
      ),
    );

    if (pin != null) {
      await controller.setPin(pin);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码已更新'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    }
  }

  /// 兑换记录面板（v1.4.0：从「审批」改为「只读记录」）
  ///
  /// **为什么不再审批？**
  /// 代币管控点在「获取」而非「消耗」。币已发给孩子，花法是孩子的
  /// 自主权，家长在这里只剩「知情权」——看得到他换了什么即可。
  ///
  /// 现实奖励仍需要家长**线下兑现**（带他去游乐园之类），
  /// 但那件事发生在生活里，不需要 App 里的一个「同意」按钮。
  void _showExchangeApproval(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(exchangeLogsProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
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
              '兑换记录',
              style: TextStyle(
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.spaceXs),
            Text(
              '孩子的选择由他自己负责，这里只做记录',
              style: TextStyle(
                fontSize: AppSizes.fontCaption,
                color: AppColors.textHint,
              ),
            ),
            SizedBox(height: AppSizes.spaceLg),

            if (logs.isEmpty)
              const EmptyPlaceholder(
                emoji: '🛍️',
                text: '还没有兑换记录',
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: AppSizes.spaceMd),
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    return Container(
                      padding: EdgeInsets.all(AppSizes.spaceLg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Text(log.itemIcon,
                              style: const TextStyle(fontSize: 32)),
                          SizedBox(width: AppSizes.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.itemName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppSizes.fontBody,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: AppSizes.spaceXs),
                                Text(
                                  '花费 ${log.costCoin} ${log.coinType.emoji} · ${_fmtDate(log.exchangeTime)}',
                                  style: TextStyle(
                                    fontSize: AppSizes.fontCaption,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 状态标签（v1.4.0 起基本恒为「已完成」）
                          TagChip(
                            text: log.status.label,
                            color: log.status == ExchangeStatus.done
                                ? AppColors.successLight
                                : AppColors.surfaceVariant,
                            textColor: log.status == ExchangeStatus.done
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontSize: AppSizes.fontTiny,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 日期简写：`M月D日`
  static String _fmtDate(DateTime dt) => '${dt.month}月${dt.day}日';

  /// 家长设置面板
  void _showParentSettings(BuildContext context, WidgetRef ref) {
    final controller = ref.read(shopControllerProvider);
    final settings = ref.read(settingsProvider);

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
              '家长设置',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.spaceXl),

            // 防作弊说明
            Container(
              padding: EdgeInsets.all(AppSizes.spaceLg),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('🛡️', style: TextStyle(fontSize: 18)),
                      SizedBox(width: AppSizes.spaceSm),
                      Text(
                        '防作弊机制',
                        style: TextStyle(
                          fontSize: AppSizes.fontBody,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSizes.spaceSm),
                  Text(
                    '孩子在专注时切出 App 超过 '
                    '${settings.allowAbandonMinutes} 分钟，'
                    '本次计时将自动作废，不发放任何奖励。',
                    style: TextStyle(
                      fontSize: AppSizes.fontCaption,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSizes.spaceLg),

            if (!controller.hasPin)
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _changePin(context, ref);
                },
                child: const Text('设置家长密码'),
              )
            else
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _changePin(context, ref);
                },
                child: const Text('修改家长密码'),
              ),
          ],
        ),
      ),
    );
  }
}

/// 功能入口配置
class _MenuEntry {
  const _MenuEntry({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;
}

/// 通用选项弹窗构造
///
/// 注意：直接接收 [context]（来自 showModalBottomSheet 的 builder），
/// 不要使用全局变量持有 context，否则页面销毁后会崩溃。
Widget _optionSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<String> options,
  required int selectedIndex,
  required ValueChanged<int> onSelected,
}) {
  return Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.7,
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
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizes.fontCaption,
              color: AppColors.textHint,
            ),
          ),
        ],
        SizedBox(height: AppSizes.spaceLg),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: List.generate(options.length, (i) {
                final selected = i == selectedIndex;
                return GestureDetector(
                  onTap: () => onSelected(i),
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
        ),
      ],
    ),
  );
}
