import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import 'core_providers.dart';
import 'pet_providers.dart';

/// 指定商店的商品列表（全局配置，不受孩子影响）
final shopItemsProvider =
    Provider.family<List<ShopItem>, ShopType>((ref, shopType) {
  final db = ref.watch(databaseProvider);
  return db.shopItems.values
      .cast<ShopItem>()
      .where((s) => s.shopType == shopType && s.isEnabled)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

/// 当前孩子的背包
final inventoryProvider = Provider<List<InventoryItem>>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return [];
  return ref.watch(databaseProvider).getInventory(childId);
});

/// 背包中的食物列表（用于喂食选择弹窗）
final inventoryFoodProvider = Provider<List<InventoryItem>>((ref) {
  return ref.watch(inventoryProvider)
      .where((i) => i.itemType == ShopItemType.food && i.quantity > 0)
      .toList();
});

/// 当前孩子的兑换记录
final exchangeLogsProvider = Provider<List<ExchangeLog>>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return [];
  return ref.watch(databaseProvider).getExchangeLogs(childId);
});

/// 待审批的兑换记录（家长审批入口的红点数据源）
final pendingExchangeLogsProvider = Provider<List<ExchangeLog>>((ref) {
  return ref.watch(exchangeLogsProvider)
      .where((e) => e.status == ExchangeStatus.pending)
      .toList();
});

/// 商品是否已解锁（对应宠物等级解锁规则）
final shopItemUnlockedProvider =
    Provider.family<bool, ShopItem>((ref, item) {
  final pet = ref.watch(activePetProvider);
  if (pet == null) return item.unlockLevel <= 1;
  return pet.level >= item.unlockLevel;
});

/// 兑换请求的校验结果
///
/// v1.4.0 简化：不再有 `needPin` 分支 —— 兑换一律不验密码。
/// 保留枚举是为了不破坏既有调用点，两个值语义统一为
/// 「够不够钱」。
enum ExchangeCheckResult {
  /// 余额不足 —— 宠物卖萌拒绝
  notEnoughCoin,

  /// 余额充足 —— 可直接兑换（v1.4.0 起不再需要家长密码）
  ok,
}

/// 商店 / 兑换控制器
class ShopController {
  ShopController(this._db, this._ref);

  final DatabaseService _db;
  final Ref _ref;

  void _bump() => _ref.read(dataRevisionProvider.notifier).bump();

  /// 兑换流程第 1 步：判断余额
  ///
  /// 余额不足时返回 [ExchangeCheckResult.notEnoughCoin]，让宠物卖萌拒绝；
  /// 足够则返回 [ExchangeCheckResult.ok]，UI 直接进入确认 → 兑换。
  ExchangeCheckResult checkBalance(Child child, ShopItem item) {
    final balance = item.coinType == RewardType.wishCoin
        ? child.wishCoin
        : child.petCoin;
    return balance >= item.price
        ? ExchangeCheckResult.ok
        : ExchangeCheckResult.notEnoughCoin;
  }

  /// 余额还差多少（用于宠物提示文案）
  int shortfall(Child child, ShopItem item) {
    final balance = item.coinType == RewardType.wishCoin
        ? child.wishCoin
        : child.petCoin;
    final diff = item.price - balance;
    return diff > 0 ? diff : 0;
  }

  /// 校验家长 PIN（从本地读取哈希值比对）
  bool verifyPin(String pin) => _db.verifyParentPin(pin);

  /// 是否已设置过 PIN
  bool get hasPin => _db.getSettings().hasSetPin;

  /// 设置 / 修改家长 PIN
  Future<void> setPin(String pin) async {
    await _db.setParentPin(pin);
    _bump();
  }

  /// 兑换流程第 3 步：扣币 + 写记录
  ///
  /// **v1.4.0：全部自动完成，不再有「待审批」状态。**
  ///
  /// 旧逻辑是「宠物商品即时到账，现实奖励转待审批」。但用户的主张
  /// 很明确：代币一旦给孩子就是他的，怎么花由他决定。所以现实奖励
  /// 也直接标记为已完成，家长只需**实际兑现**（带他去游乐园之类），
  /// 而不是在 App 里点「批准」。
  ///
  /// 这样兑换记录里全是「已完成」，家长仍能看到孩子换了什么，
  /// 只是不再被要求审批。
  Future<ExchangeLog> performExchange({
    required Child child,
    required ShopItem item,
  }) async {
    final log = await _db.performExchange(
      childId: child.id,
      item: item,
      autoApprove: true,
    );

    // 商品直接入背包
    await _db.addToInventory(child.id, item);

    // 兑换会推进「累计兑换」类勋章进度
    await _db.refreshAchievements(child.id);

    _bump();
    return log;
  }

  /// 家长审批兑换记录
  Future<void> approveExchange(String logId, bool approved) async {
    await _db.approveExchange(logId, approved);
    _bump();
  }

  /// 余额不足时，让宠物说拒绝台词
  String coinNotEnoughDialogue() => _db.pickDialogue(
        trigger: PetDialogueTrigger.coinNotEnough,
      );

  /// 兑换成功后的宠物欢呼台词
  String exchangeDoneDialogue() => _db.pickDialogue(
        trigger: PetDialogueTrigger.exchangeDone,
      );
}

final shopControllerProvider = Provider<ShopController>((ref) {
  return ShopController(ref.watch(databaseProvider), ref);
});
