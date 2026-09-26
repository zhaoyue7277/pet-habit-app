import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/habit_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import '../widgets/pin_dialog.dart';

/// 家长验收队列（v1.4.0 新增）
///
/// **为什么需要这一页？**
///
/// 采纳「路线 C：延迟确认」后，孩子打卡不再立即发奖励，而是进入
/// 待验收队列。家长需要一个集中的地方去「通过 / 驳回」，而不是被
/// 一条条推送打扰。
///
/// **设计取向：**
/// - **批量优先**：默认给「全部通过」按钮，因为大多数情况孩子是
///   真做了，逐条点太累；只有个别造假时才逐条驳回。
/// - **驳回要写原因**：孩子看到理由才知道下次怎么改，纯拒绝会
///   打击积极性（这是「情绪价值」的一部分）。
/// - **驳回后仍可补交**：被驳回的记录在乐园页显示 ↩️，孩子补做后
///   重新提交即可，不设惩罚。
///
/// 进入本页需要家长密码（复用 [PinInputDialog]），避免孩子自己
/// 点「全部通过」——那就绕过了整个机制。
class CheckInVerifyPage extends ConsumerStatefulWidget {
  const CheckInVerifyPage({super.key});

  @override
  ConsumerState<CheckInVerifyPage> createState() => _CheckInVerifyPageState();
}

class _CheckInVerifyPageState extends ConsumerState<CheckInVerifyPage> {
  /// 是否已通过家长密码校验
  bool _unlocked = false;

  /// 正在处理中的记录（避免重复点击）
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    // 进页即要求密码（build 之后弹，否则拿不到有效 context）
    WidgetsBinding.instance.addPostFrameCallback((_) => _requirePin());
  }

  Future<void> _requirePin() async {
    final db = ref.read(databaseProvider);
    // 未设置密码时直接放行（首次使用场景）
    if (!db.hasParentPin()) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }
    final ok = await PinInputDialog.show(
      context,
      title: '家长验证',
      subtitle: '请输入家长密码查看验收队列',
      onVerify: (pin) => db.verifyParentPin(pin),
    );
    if (!mounted) return;
    if (ok == true) {
      setState(() => _unlocked = true);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('打卡验收'),
        centerTitle: true,
      ),
      body: _unlocked ? _buildBody() : _buildLocked(),
    );
  }

  Widget _buildLocked() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔒', style: TextStyle(fontSize: 48)),
          SizedBox(height: AppSizes.spaceLg),
          Text(
            '需要家长密码',
            style: TextStyle(
              fontSize: AppSizes.fontLabel,
              color: AppColors.textHint,
            ),
          ),
          SizedBox(height: AppSizes.spaceLg),
          BouncyButton(
            onPressed: _requirePin,
            color: AppColors.primary,
            child: const Text('输入密码'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final pending = ref.watch(pendingCheckInsProvider);
    final child = ref.watch(activeChildProvider);

    if (pending.isEmpty) {
      return _buildEmpty();
    }

    return Column(
      children: [
        _buildHeader(pending.length, child?.name ?? '孩子'),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              AppSizes.spaceLg,
              AppSizes.spaceSm,
              AppSizes.spaceLg,
              AppSizes.spaceXxl,
            ),
            itemCount: pending.length,
            separatorBuilder: (_, __) => SizedBox(height: AppSizes.spaceMd),
            itemBuilder: (context, i) => _buildRecordCard(pending[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 56)),
          SizedBox(height: AppSizes.spaceLg),
          Text(
            '没有待验收的打卡',
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSizes.spaceSm),
          Text(
            '孩子提交打卡后会出现在这里',
            style: TextStyle(
              fontSize: AppSizes.fontCaption,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int count, String childName) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppSizes.spaceLg,
        AppSizes.spaceSm,
        AppSizes.spaceLg,
        AppSizes.spaceSm,
      ),
      padding: EdgeInsets.all(AppSizes.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$childName 有 $count 条待验收',
                  style: TextStyle(
                    fontSize: AppSizes.fontHeadline,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: AppSizes.spaceXs),
                Text(
                  '确认真实完成后奖励才会发放',
                  style: TextStyle(
                    fontSize: AppSizes.fontCaption,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSizes.spaceMd),
          BouncyButton(
            height: AppSizes.buttonSmallHeight,
            color: Colors.white,
            onPressed: _busy.isEmpty ? _approveAll : null,
            child: Text(
              '全部通过',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: AppSizes.fontLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(HabitCheckIn record) {
    final db = ref.read(databaseProvider);
    final habit = db.habits.get(record.habitId) as Habit?;
    final busy = _busy.contains(record.id);

    return AppCard(
      padding: EdgeInsets.all(AppSizes.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppScale.s(44),
                height: AppScale.s(44),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Text(
                  habit?.iconEmoji ?? '⭐',
                  style: TextStyle(fontSize: AppScale.s(22)),
                ),
              ),
              SizedBox(width: AppSizes.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit?.name ?? '已删除的习惯',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppSizes.fontLabel,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSizes.spaceXs),
                    Text(
                      '${_fmtTime(record.checkInTime)} 提交',
                      style: TextStyle(
                        fontSize: AppSizes.fontCaption,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              // 奖励预览
              if (habit != null)
                TagChip(
                  text:
                      '${habit.checkInRewardType.emoji} +${habit.checkInRewardValue}',
                  color: AppColors.accent.withValues(alpha: 0.22),
                  textColor: AppColors.accentDark,
                  fontSize: AppSizes.fontTiny,
                ),
            ],
          ),
          SizedBox(height: AppSizes.spaceLg),
          Row(
            children: [
              Expanded(
                child: BouncyButton(
                  height: AppSizes.buttonSmallHeight,
                  color: AppColors.surfaceVariant,
                  onPressed: busy ? null : () => _reject(record),
                  child: Text(
                    '驳回',
                    style: TextStyle(
                      color: AppColors.secondaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSizes.spaceMd),
              Expanded(
                flex: 2,
                child: BouncyButton(
                  height: AppSizes.buttonSmallHeight,
                  color: AppColors.success,
                  onPressed: busy ? null : () => _approve(record),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '确认通过',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
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

  // ==================== 操作 ====================

  Future<void> _approve(HabitCheckIn record) async {
    setState(() => _busy.add(record.id));
    final controller = ref.read(habitControllerProvider);
    final reward = await controller.approveCheckIn(record.id);
    if (!mounted) return;
    setState(() => _busy.remove(record.id));

    final db = ref.read(databaseProvider);
    final habit = db.habits.get(record.habitId) as Habit?;
    final emoji = habit?.checkInRewardType.emoji ?? '💛';

    _toast(
      reward > 0 ? '已通过，发放 $emoji +$reward' : '已通过',
      AppColors.success,
    );
  }

  Future<void> _approveAll() async {
    final controller = ref.read(habitControllerProvider);
    final pending = ref.read(pendingCheckInsProvider);
    setState(() => _busy.addAll(pending.map((e) => e.id)));

    final reward = await controller.approveAllPending();
    if (!mounted) return;
    setState(() => _busy.clear());

    _toast(
      reward > 0 ? '全部通过，共发放 $reward 奖励' : '全部通过',
      AppColors.success,
    );
  }

  Future<void> _reject(HabitCheckIn record) async {
    final reason = await _askRejectReason();
    if (reason == null) return; // 用户取消

    setState(() => _busy.add(record.id));
    await ref.read(habitControllerProvider).rejectCheckIn(
          record.id,
          reason: reason.isEmpty ? null : reason,
        );
    if (!mounted) return;
    setState(() => _busy.remove(record.id));
    _toast('已驳回，孩子补做后可重新提交', AppColors.warning);
  }

  /// 弹窗询问驳回原因（可留空）
  Future<String?> _askRejectReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        title: Text(
          '驳回这条打卡',
          style: TextStyle(
            fontSize: AppSizes.fontHeadline,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '写一句原因，让孩子知道下次怎么做（可留空）',
              style: TextStyle(
                fontSize: AppSizes.fontCaption,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSizes.spaceMd),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 60,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '例如：今天没有真的读书哦',
                fillColor: AppColors.surfaceVariant,
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              '确认驳回',
              style: TextStyle(
                color: AppColors.secondaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _toast(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: TextStyle(
            fontSize: AppSizes.fontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final sameDay = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (sameDay) return '今天 $hm';
    return '${dt.month}月${dt.day}日 $hm';
  }
}
