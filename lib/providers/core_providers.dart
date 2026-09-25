import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/database_service.dart';

/// 数据服务单例 Provider
final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

// ===================================================================
// 全局刷新信号
// ===================================================================

/// 全局数据版本号
///
/// **为什么需要它：** Hive 的 Box 变化可以监听，但多表联动的场景
/// （例如完成任务会同时改 Task 与 Child 两张表）监听会很零碎。
/// 统一用一个自增计数作为「数据已变更」信号，
/// 任何需要联动的 Provider `ref.watch` 它即可自动重算。
class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  /// 通知全局：数据已变更
  void bump() => state = state + 1;
}

final dataRevisionProvider =
    NotifierProvider<DataRevision, int>(DataRevision.new);

/// 供 UI 层调用的便捷入口
extension DataRevisionX on WidgetRef {
  /// 数据变更后刷新全局状态
  void bumpRevision() => read(dataRevisionProvider.notifier).bump();
}

// ===================================================================
// 孩子相关
// ===================================================================

/// 全部孩子列表
final allChildrenProvider = Provider<List<Child>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(databaseProvider).getAllChildren();
});

/// 当前激活的孩子（多孩隔离的核心入口）
///
/// 业务层一律通过它取 childId，绝不硬编码。
final activeChildProvider = Provider<Child?>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(databaseProvider).getActiveChild();
});

/// 当前孩子 ID（可能为空：尚未建档）
final activeChildIdProvider = Provider<String?>((ref) {
  return ref.watch(activeChildProvider)?.id;
});

/// 当前心愿币余额
final wishCoinProvider = Provider<int>((ref) {
  return ref.watch(activeChildProvider)?.wishCoin ?? 0;
});

/// 当前宠物币余额
final petCoinProvider = Provider<int>((ref) {
  return ref.watch(activeChildProvider)?.petCoin ?? 0;
});

/// 孩子操作控制器
class ChildController {
  ChildController(this._db, this._ref);

  final DatabaseService _db;
  final Ref _ref;

  /// 新建孩子档案并设为激活
  Future<Child> createChild({
    required String name,
    int avatarIndex = 0,
    int grade = 1,
  }) async {
    final child = Child(
      id: _db.newId('child_'),
      name: name,
      avatarIndex: avatarIndex,
      grade: grade,
      createdAt: DateTime.now(),
      isActive: true,
    );
    // 先取消其他孩子的激活状态
    for (final c in _db.getAllChildren()) {
      if (c.isActive) await _db.saveChild(c.copyWith(isActive: false));
    }
    await _db.saveChild(child);
    _ref.read(dataRevisionProvider.notifier).bump();
    return child;
  }

  /// 切换当前孩子（数据完全隔离）
  Future<void> switchChild(String childId) async {
    await _db.switchActiveChild(childId);
    _ref.read(dataRevisionProvider.notifier).bump();
  }

  /// 更新孩子信息
  Future<void> updateChild(Child child) async {
    await _db.saveChild(child);
    _ref.read(dataRevisionProvider.notifier).bump();
  }

  /// 删除孩子及其全部数据
  Future<void> deleteChild(String childId) async {
    await _db.deleteChild(childId);
    _ref.read(dataRevisionProvider.notifier).bump();
  }
}

final childControllerProvider = Provider<ChildController>((ref) {
  return ChildController(ref.watch(databaseProvider), ref);
});
