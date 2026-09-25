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
enum ExchangeCheckResult {
  /// 余额不足 —— 直接宠物卖萌拒绝，**不需要**弹 PIN
  notEnoughCoin,

  /// 余额充足 —— 需要弹家长 PIN 校验
  needPin,
}

/// 商店 / 兑换控制器
class ShopController {
  ShopController(this._db, this._ref);

  final DatabaseService _db;
  final Ref _ref;

  void _bump() => _ref.read(dataRevisionProvider.notifier).bump();

  /// 兑换流程第 1 步：判断余额
  ///
  /// **对应需求的关键逻辑：**
  /// 余额不足时**无需弹密码框**，直接返回 notEnoughCoin 让宠物卖萌拒绝。
  ExchangeCheckResult checkBalance(Child child, ShopItem item) {
    final balance = item.coinType == RewardType.wishCoin
        ? child.wishCoin
        : child.petCoin;
    return balance >= item.price
        ? ExchangeCheckResult.needPin
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

  /// 兑换流程第 3 步：验证通过后扣币 + 写记录
  ///
  /// **宠物币商品自动完成，心愿币商品（现实奖励）进入待审批。**
  Future<ExchangeLog> performExchange({
    required Child child,
    required ShopItem item,
  }) async {
    // 现实奖励需要家长审批；宠物商品即时到账
    final autoApprove = item.shopType == ShopType.monster;

    final log = await _db.performExchange(
      childId: child.id,
      item: item,
      autoApprove: autoApprove,
    );

    // 宠物商品直接入背包
    if (item.shopType == ShopType.monster) {
      await _db.addToInventory(child.id, item);
    }

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
