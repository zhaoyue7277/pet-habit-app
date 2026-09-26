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
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.spaceLg,
                      AppSizes.spaceSm,
                      AppSizes.spaceLg,
                      AppSizes.bottomNavHeight + 40,
                    ),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
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
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.spaceLg,
        vertical: AppSizes.spaceMd,
      ),
      child: Row(
        children: ShopType.values.map((type) {
          final selected = _currentShop == type;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.spaceSm),
              child: GestureDetector(
                onTap: () => setState(() => _currentShop = type),
                child: AnimatedContainer(
                  duration: AppSizes.durationFast,
                  padding: EdgeInsets.symmetric(
                    vertical: AppSizes.spaceMd,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: AppColors.primaryGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
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
                      SizedBox(height: AppSizes.spaceXs),
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
      padding: EdgeInsets.symmetric(horizontal: AppSizes.spaceLg),
      child: AppCard(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.spaceLg,
          vertical: AppSizes.spaceMd,
        ),
        child: Row(
          children: [
            Text(
              coinType.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            SizedBox(width: AppSizes.spaceSm),
            Text(
              '${coinType.label}余额',
              style: TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '$balance',
              style: TextStyle(
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            SizedBox(width: AppSizes.spaceMd),

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
      padding: EdgeInsets.all(AppSizes.spaceMd),
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
                              style: TextStyle(
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

            SizedBox(height: AppSizes.spaceSm),

            // ---------- 商品名 ----------
            // 【v1.4.0】允许换 2 行：2 列卡片在窄屏下每格约 165px，
            // 长商品名（如「周末去游乐园」）单行会被截断。
            Text(
              item.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            // ---------- 规格 ----------
            if (item.specLabel.isNotEmpty) ...[
              SizedBox(height: AppSizes.spaceXs),
              Text(
                item.specLabel,
                style: TextStyle(
                  fontSize: AppSizes.fontCaption,
                  color: AppColors.textHint,
                ),
              ),
            ],

            SizedBox(height: AppSizes.spaceSm),

            // ---------- 价格按钮 ----------
            Container(
              padding: EdgeInsets.symmetric(
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
                  SizedBox(width: AppSizes.spaceXs),
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

  /// 点击商品 → 触发兑换
  ///
  /// **v1.4.0 重要变更：彻底取消家长密码**
  ///
  /// **为什么取消？** 因为管控点放错了位置。
  ///
  /// 代币管控的正确位置是「**获取**」环节 —— 孩子不能凭空产生代币，
  /// 每一枚币都必须来自家长的认可（打卡验收、任务完成）。一旦币发到了
  /// 孩子账户，所有权就已经转移了，这时家长再拦「怎么花」，
  /// 本质上是在否定自己刚给出的承诺。
  ///
  /// 更重要的是**教育意义**：孩子需要练习「自己决定 + 自己承担」。
  /// 花 50 币换了个不喜欢的皮肤？那就记住了下次要看清。
  /// 这个「换错了也得认」的体验，比家长替他做决定有价值得多。
  ///
  /// **现在的流程**：余额够 → 直接扣币 → 撒花。
  /// 只保留一个「确认」弹窗（防误触），不涉及身份验证。
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
      // 余额不足：宠物卖萌拒绝
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

    // ---------- 第 2 步：防误触确认（不是身份验证） ----------
    final confirmed = await _confirmExchange(child, item);
    if (confirmed != true) return;

    // ---------- 第 3 步：直接兑换 ----------
    await _performExchange(child, item);
  }

  /// 兑换前的「点一下确认」——只防误触，不验身份
  ///
  /// 与旧版的区别：不再需要任何密码。这里只是一个「你确定要花
  /// N 个币换这个吗」的常规二次确认，任何 App 的消费操作都该有。
  Future<bool?> _confirmExchange(Child child, ShopItem item) {
    final balance = item.coinType == RewardType.wishCoin
        ? child.wishCoin
        : child.petCoin;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        title: Row(
          children: [
            Text(item.iconEmoji, style: const TextStyle(fontSize: 28)),
            SizedBox(width: AppSizes.spaceSm),
            Expanded(
              child: Text(
                '确认兑换',
                style: TextStyle(
                  fontSize: AppSizes.fontHeadline,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: TextStyle(
                fontSize: AppSizes.fontBody,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.spaceMd),
            // 余额变化预览：让孩子清楚看到「花掉多少、还剩多少」
            Row(
              children: [
                Text(
                  '${item.coinType.emoji} $balance',
                  style: TextStyle(
                    fontSize: AppSizes.fontLabel,
                    color: AppColors.textSecondary,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceSm,
                  ),
                  child: const Text('→'),
                ),
                Text(
                  '${item.coinType.emoji} ${balance - item.price}',
                  style: TextStyle(
                    fontSize: AppSizes.fontLabel,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.spaceSm),
            Text(
              '花掉 ${item.price} ${item.coinType.label}，换掉就不退咯～',
              style: TextStyle(
                fontSize: AppSizes.fontCaption,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              '再想想',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '就换这个',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
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
                fontSize: AppSizes.fontHeadline,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSizes.spaceLg),
            if (logs.isEmpty)
              Padding(
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
                      SizedBox(height: AppSizes.spaceSm),
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
      padding: EdgeInsets.all(AppSizes.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Text(log.itemIcon, style: const TextStyle(fontSize: 28)),
          SizedBox(width: AppSizes.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.itemName,
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${log.exchangeTime.month}月${log.exchangeTime.day}日 '
                  '${log.exchangeTime.hour.toString().padLeft(2, '0')}:'
                  '${log.exchangeTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
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
                style: TextStyle(
                  fontSize: AppSizes.fontLabel,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppSizes.spaceXs),
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
          style: TextStyle(
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
