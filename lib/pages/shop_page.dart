import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/pet_providers.dart';
import '../providers/shop_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import '../widgets/pin_dialog.dart';

/// 心愿商店 / 怪兽商店页面
///
/// **对应截图 5 与需求模块 3：**
/// - 顶部两个 Tab：「心愿商店 ❤️」（现实奖励）与「怪兽商店 🐾」（宠物商品）
/// - 余额条显示当前心愿币
/// - 商品卡：图片 + 名称 + 规格 + 价格
/// - 兑换流程：余额不足→宠物卖萌拒绝；余额足→家长 PIN→扣币→写记录→撒花
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  ShopType _currentShop = ShopType.wish;

  @override
  Widget build(BuildContext context) {
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

    final items = ref.watch(shopItemsProvider(_currentShop));

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ---------- 顶部商店切换 Tab ----------
          _buildShopTabs(),

          // ---------- 余额条 ----------
          _buildBalanceBar(child),

          // ---------- 商品列表 ----------
          Expanded(
            child: items.isEmpty
                ? const EmptyPlaceholder(
                    emoji: '🏪',
                    text: '商店正在补货中～',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.spaceLg,
                      AppSizes.spaceSm,
                      AppSizes.spaceLg,
                      AppSizes.bottomNavHeight + 40,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSizes.spaceLg,
                      crossAxisSpacing: AppSizes.spaceLg,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _buildItemCard(
                      child,
                      items[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 商店切换 Tab（对应截图：两个斜挂的招牌样式）
  Widget _buildShopTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceLg,
        vertical: AppSizes.spaceMd,
      ),
      child: Row(
        children: ShopType.values.map((type) {
          final selected = _currentShop == type;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceSm),
              child: GestureDetector(
                onTap: () => setState(() => _currentShop = type),
                child: AnimatedContainer(
                  duration: AppSizes.durationFast,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSizes.spaceMd,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: AppColors.primaryGradient,
                          )
                        : null,
                    color: selected ? null : AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(
                      color: selected
                          ? AppColors.secondaryDark
                          : AppColors.divider,
                      width: 2,
                    ),
                    boxShadow: selected ? AppShadows.card : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        type.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: AppSizes.spaceXs),
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: AppSizes.fontBody,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 余额条
  Widget _buildBalanceBar(Child child) {
    final balance = _currentShop == ShopType.wish
        ? child.wishCoin
        : child.petCoin;
    final coinType = _currentShop == ShopType.wish
        ? RewardType.wishCoin
        : RewardType.petCoin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceLg,
          vertical: AppSizes.spaceMd,
        ),
        child: Row(
          children: [
            Text(
              coinType.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: AppSizes.spaceSm),
            Text(
              '${coinType.label}余额',
              style: const TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '$balance',
              style: const TextStyle(
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: AppSizes.spaceMd),

            // 兑换记录入口（对应截图：清单图标）
            GestureDetector(
              onTap: () => _showExchangeLogs(child),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 22,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 商品卡片
  Widget _buildItemCard(Child child, ShopItem item) {
    final unlocked = ref.watch(shopItemUnlockedProvider(item));
    final balance = item.coinType == RewardType.wishCoin
        ? child.wishCoin
        : child.petCoin;
    final affordable = balance >= item.price;

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      onTap: () => _onExchangeTap(child, item),
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.55,
        child: Column(
          children: [
            // ---------- 商品图 ----------
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.iconEmoji,
                        style: const TextStyle(fontSize: 42),
                      ),
                    ),
                    // 未解锁遮罩
                    if (!unlocked)
                      Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMd),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_rounded,
                                color: Colors.white, size: 22),
                            Text(
                              'Lv.${item.unlockLevel}',
                              style: const TextStyle(
                                fontSize: AppSizes.fontTiny,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSizes.spaceSm),

            // ---------- 商品名 ----------
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            // ---------- 规格 ----------
            if (item.specLabel.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spaceXs),
              Text(
                item.specLabel,
                style: const TextStyle(
                  fontSize: AppSizes.fontCaption,
                  color: AppColors.textHint,
                ),
              ),
            ],

            const SizedBox(height: AppSizes.spaceSm),

            // ---------- 价格按钮 ----------
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSizes.spaceSm,
              ),
              decoration: BoxDecoration(
                color: affordable && unlocked
                    ? AppColors.secondaryLight
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.coinType.emoji,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: AppSizes.spaceXs),
                  Text(
                    '${item.price}',
                    style: TextStyle(
                      fontSize: AppSizes.fontBody,
                      fontWeight: FontWeight.w800,
                      color: affordable && unlocked
                          ? AppColors.secondaryDark
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 兑换流程（核心） ====================

  /// 点击商品 → 触发兑换流程
  ///
  /// **流程（对应需求模块 3）：**
  /// 1. 判断余额：
  ///    - 不足 → **不弹密码框**，宠物卖萌拒绝；
  ///    - 足够 → 弹出家长 PIN 输入框。
  /// 2. PIN 验证通过 → 扣除金币 → 写入兑换记录 → 撒花欢呼动画。
  Future<void> _onExchangeTap(Child child, ShopItem item) async {
    // 未解锁提示
    final unlocked = item.shopType == ShopType.monster
        ? (ref.read(activePetProvider)?.level ?? 1) >= item.unlockLevel
        : true;
    if (!unlocked) {
      _toast('需要宠物达到 Lv.${item.unlockLevel} 才能解锁哦～');
      return;
    }

    final shopController = ref.read(shopControllerProvider);

    // ---------- 第 1 步：判断余额 ----------
    final check = shopController.checkBalance(child, item);

    if (check == ExchangeCheckResult.notEnoughCoin) {
      // 余额不足：直接宠物卖萌拒绝，**无需弹密码框**
      await showDialog<void>(
        context: context,
        builder: (_) => CoinNotEnoughDialog(
          dialogue: shopController.coinNotEnoughDialogue(),
          shortfall: shopController.shortfall(child, item),
          coinEmoji: item.coinType.emoji,
        ),
      );
      return;
    }

    // ---------- 第 2 步：余额充足 → 弹出家长 PIN ----------
    // 若家长尚未设置过 PIN，先引导设置
    if (!shopController.hasPin) {
      await _setupPinThenExchange(child, item);
      return;
    }

    final verified = await showDialog<bool>(
      context: context,
      builder: (_) => PinInputDialog(
        title: '请家长输入密码',
        subtitle: '兑换「${item.name}」需要家长确认',
        onVerify: shopController.verifyPin,
      ),
    );

    if (verified != true) return;

    // ---------- 第 3 步：验证通过 → 扣币 + 写记录 + 撒花 ----------
    await _performExchange(child, item);
  }

  /// 尚未设置 PIN 时：先设置再兑换
  Future<void> _setupPinThenExchange(Child child, ShopItem item) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => PinInputDialog(
        title: '设置家长密码',
        subtitle: '用于确认孩子的兑换申请，请牢记',
        isSettingMode: true,
        onVerify: (_) => true,
      ),
    );

    if (pin == null) return;
    await ref.read(shopControllerProvider).setPin(pin);

    // 设置完成后直接继续兑换
    await _performExchange(child, item);
  }

  /// 执行兑换
  Future<void> _performExchange(Child child, ShopItem item) async {
    final log = await ref.read(shopControllerProvider).performExchange(
          child: child,
          item: item,
        );

    if (!mounted) return;

    // 撒花庆祝
    await showDialog<void>(
      context: context,
      builder: (_) => ExchangeSuccessDialog(
        itemName: item.name,
        itemIcon: item.iconEmoji,
        dialogue: log.status == ExchangeStatus.pending
            ? '已经告诉爸爸妈妈啦，等他们确认就能兑现哦～'
            : ref.read(shopControllerProvider).exchangeDoneDialogue(),
      ),
    );
  }

  /// 兑换记录列表
  void _showExchangeLogs(Child child) {
    final logs = ref.read(exchangeLogsProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        margin: const EdgeInsets.all(AppSizes.spaceLg),
        padding: const EdgeInsets.all(AppSizes.spaceXl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '兑换记录',
              style: TextStyle(
                fontSize: AppSizes.fontHeadline,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLg),
            if (logs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSizes.spaceXl),
                child: EmptyPlaceholder(
                  emoji: '📋',
                  text: '还没有兑换记录',
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.spaceSm),
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    return _buildLogTile(log);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 单条兑换记录
  Widget _buildLogTile(ExchangeLog log) {
    final (statusColor, statusText) = switch (log.status) {
      ExchangeStatus.pending => (AppColors.warning, '待审批'),
      ExchangeStatus.done => (AppColors.success, '已完成'),
      ExchangeStatus.rejected => (AppColors.error, '已拒绝'),
    };

    return Container(
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Text(log.itemIcon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: AppSizes.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.itemName,
                  style: const TextStyle(
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${log.exchangeTime.month}月${log.exchangeTime.day}日 '
                  '${log.exchangeTime.hour.toString().padLeft(2, '0')}:'
                  '${log.exchangeTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: AppSizes.fontCaption,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${log.costCoin} ${log.coinType.emoji}',
                style: const TextStyle(
                  fontSize: AppSizes.fontLabel,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.spaceXs),
              TagChip(
                text: statusText,
                color: statusColor.withValues(alpha: 0.2),
                textColor: statusColor,
                fontSize: AppSizes.fontTiny,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: AppSizes.fontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }
}
