import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

import '../models/models.dart';
import 'hive_init.dart';

/// 数据访问服务层
///
/// **设计要点：**
/// 1. 所有业务表查询**强制携带 childId**，实现多孩数据完全隔离；
/// 2. 提供同步读取（UI 直接调用）与异步写入两类方法；
/// 3. App 首次启动时通过 [seedIfNeeded] 注入全局配置数据（勋章、商品、习惯库、台词）。
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  final Random _random = Random();

  // ==================== Box 快捷访问 ====================
  Box get children => Hive.box(HiveInit.boxChildren);
  Box get pets => Hive.box(HiveInit.boxPets);
  Box get tasks => Hive.box(HiveInit.boxTasks);
  Box get habits => Hive.box(HiveInit.boxHabits);
  Box get checkIns => Hive.box(HiveInit.boxCheckIns);
  Box get exchangeLogs => Hive.box(HiveInit.boxExchangeLogs);
  Box get achievementDefs => Hive.box(HiveInit.boxAchievementDefs);
  Box get childAchievements => Hive.box(HiveInit.boxChildAchievements);
  Box get shopItems => Hive.box(HiveInit.boxShopItems);
  Box get inventory => Hive.box(HiveInit.boxInventory);
  Box get habitTemplates => Hive.box(HiveInit.boxHabitTemplates);
  Box get petDialogues => Hive.box(HiveInit.boxPetDialogues);
  Box get dailyNotes => Hive.box(HiveInit.boxDailyNotes);
  Box get pomodoroSessions => Hive.box(HiveInit.boxPomodoroSessions);
  Box get recordings => Hive.box(HiveInit.boxRecordings);

  /// 设置表（单例，固定 key）
  static const String _settingsKey = 'app_settings';
  Box<AppSettings> get settingsBox =>
      Hive.box<AppSettings>(HiveInit.boxSettings);

  /// 读取全局设置（不存在则创建默认值）
  AppSettings getSettings() {
    var s = settingsBox.get(_settingsKey);
    if (s == null) {
      s = AppSettings();
      settingsBox.put(_settingsKey, s);
    }
    return s;
  }

  /// 保存全局设置
  Future<void> saveSettings(AppSettings s) =>
      settingsBox.put(_settingsKey, s);

  // ==================== 工具方法 ====================

  /// 生成唯一 ID
  String newId([String prefix = '']) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rnd = _random.nextInt(999999).toString().padLeft(6, '0');
    return '$prefix${ts}_$rnd';
  }

  // ==================== 孩子 ====================

  /// 全部孩子（按建档时间排序）
  List<Child> getAllChildren() {
    final list = children.values.cast<Child>().toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// 当前激活的孩子（多孩切换的核心）
  Child? getActiveChild() {
    if (children.isEmpty) return null;
    final active = children.values.cast<Child>().where((c) => c.isActive);
    if (active.isNotEmpty) return active.first;
    // 兜底：没有激活标记时取第一个
    final first = getAllChildren().first;
    return first;
  }

  /// 切换当前孩子（互斥，只保留一个 active）
  Future<void> switchActiveChild(String childId) async {
    for (final c in children.values.cast<Child>()) {
      final shouldActive = c.id == childId;
      if (c.isActive != shouldActive) {
        await children.put(c.id, c.copyWith(isActive: shouldActive));
      }
    }
  }

  Future<void> saveChild(Child child) => children.put(child.id, child);

  Future<void> deleteChild(String childId) async {
    await children.delete(childId);
    // 级联删除该孩子的全部数据，保证不留孤儿数据
    await _deleteWhere(pets, (Pet e) => e.childId == childId);
    await _deleteWhere(tasks, (Task e) => e.childId == childId);
    await _deleteWhere(habits, (Habit e) => e.childId == childId);
    await _deleteWhere(checkIns, (HabitCheckIn e) => e.childId == childId);
    await _deleteWhere(exchangeLogs, (ExchangeLog e) => e.childId == childId);
    await _deleteWhere(childAchievements, (ChildAchievement e) => e.childId == childId);
    await _deleteWhere(inventory, (InventoryItem e) => e.childId == childId);
    await _deleteWhere(dailyNotes, (DailyNote e) => e.childId == childId);
    await _deleteWhere(pomodoroSessions, (PomodoroSession e) => e.childId == childId);
    // 录音字节随记录一并删除，不残留孤儿音频
    await _deleteWhere(recordings, (Recording e) => e.childId == childId);
  }

  /// 通用按条件批量删除
  Future<void> _deleteWhere<T>(Box box, bool Function(T) test) async {
    final keys = <dynamic>[];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is T && test(value)) keys.add(key);
    }
    await box.deleteAll(keys);
  }

  // ==================== 金币 ====================

  /// 变更金币（type 指定币种，delta 可正可负）
  ///
  /// 返回变更后的余额；余额不足时**不执行扣减**并返回负数表示失败。
  Future<int> changeCoin(
    String childId,
    RewardType type,
    int delta,
  ) async {
    final child = children.get(childId) as Child?;
    if (child == null) return -1;

    final isWish = type == RewardType.wishCoin;
    final current = isWish ? child.wishCoin : child.petCoin;
    final next = current + delta;

    // 扣减时校验余额
    if (delta < 0 && next < 0) return -1;

    final updated = isWish
        ? child.copyWith(wishCoin: next)
        : child.copyWith(petCoin: next);
    await children.put(childId, updated);
    return next;
  }

  // ==================== 宠物 ====================

  /// 某个孩子的全部宠物
  List<Pet> getPets(String childId) =>
      pets.values.cast<Pet>().where((p) => p.childId == childId).toList()
        ..sort((a, b) => b.level.compareTo(a.level));

  /// 当前出战宠物
  Pet? getActivePet(String childId) {
    final child = children.get(childId) as Child?;
    if (child?.currentPetId != null) {
      final p = pets.get(child!.currentPetId) as Pet?;
      if (p != null) return p;
    }
    final list = getPets(childId);
    return list.isEmpty ? null : list.first;
  }

  Future<void> savePet(Pet pet) => pets.put(pet.id, pet);

  /// 切换出战宠物（同时更新 Child.currentPetId）
  Future<void> switchPet(String childId, String petId) async {
    for (final p in getPets(childId)) {
      final shouldBattle = p.id == petId;
      if (p.isBattle != shouldBattle) {
        await pets.put(p.id, p.copyWith(isBattle: shouldBattle));
      }
    }
    final child = children.get(childId) as Child?;
    if (child != null) {
      await children.put(childId, child.copyWith(currentPetId: petId));
    }
  }

  /// 结算宠物衰减：把实时值固化到存储字段，并刷新结算时间
  ///
  /// 应当在「读取宠物前」或「互动后」调用，避免长时间离线导致数值溢出。
  Future<Pet> settlePet(Pet pet) async {
    final now = DateTime.now();
    final settled = pet.copyWith(
      satiety: pet.currentSatiety(now),
      mood: pet.currentMood(now),
      lastDecayTime: now,
    );
    await pets.put(settled.id, settled);
    return settled;
  }

  /// 给宠物加经验，返回是否升级
  ///
  /// 采用 while 循环支持一次性连升多级（例如一次性获得大量经验）。
  Future<bool> addPetExp(String petId, int exp) async {
    final pet = pets.get(petId) as Pet?;
    if (pet == null) return false;

    var level = pet.level;
    var cur = pet.exp + exp;
    var leveledUp = false;

    while (cur >= Pet.expToNextLevel(level)) {
      cur -= Pet.expToNextLevel(level);
      level++;
      leveledUp = true;
    }

    await pets.put(petId, pet.copyWith(level: level, exp: cur));
    return leveledUp;
  }

  /// 喂食：消耗背包中的食物，提升饱食度与经验
  Future<bool> feedPet(String petId, InventoryItem food) async {
    final pet = pets.get(petId) as Pet?;
    if (pet == null) return false;
    if (food.quantity <= 0) return false;

    final settled = await settlePet(pet);
    await pets.put(
      petId,
      settled.copyWith(
        satiety: (settled.satiety + 25).clamp(0, 100),
        mood: (settled.mood + 5).clamp(0, 100),
        totalFeedCount: settled.totalFeedCount + 1,
        lastFeedTime: DateTime.now(),
      ),
    );
    await addPetExp(petId, 10);

    // 扣减背包数量，归零则移除
    if (food.quantity <= 1) {
      await inventory.delete(food.id);
    } else {
      await inventory.put(food.id, food.copyWith(quantity: food.quantity - 1));
    }
    return true;
  }

  /// 抚摸：提升心情值
  Future<void> petPet(String petId) async {
    final pet = pets.get(petId) as Pet?;
    if (pet == null) return;
    final settled = await settlePet(pet);
    await pets.put(
      petId,
      settled.copyWith(
        mood: (settled.mood + 12).clamp(0, 100),
        totalPetCount: settled.totalPetCount + 1,
        lastPetTime: DateTime.now(),
      ),
    );
    await addPetExp(petId, 3);
  }

  // ==================== 任务 ====================

  /// 某孩子的全部任务
  List<Task> getTasks(String childId) =>
      tasks.values.cast<Task>().where((t) => t.childId == childId).toList();

  /// 今日待办任务（按科目分组由 Provider 层处理）
  ///
  /// 排序规则：进行中 > 未完成 > 已完成；同状态下按优先级排序。
  List<Task> getTodayTasks(String childId, {DateTime? day}) {
    final d = day ?? DateTime.now();
    final list = getTasks(childId)
        .where((t) => t.parentTaskId == null && !t.isArchivedTask && t.shouldShowOn(d))
        .toList();

    list.sort((a, b) {
      // 进行中优先
      if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
      // 已完成靠后
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      // 按优先级
      final p = a.priority.index.compareTo(b.priority.index);
      if (p != 0) return p;
      // 按创建时间
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  /// 子任务
  List<Task> getSubTasks(String parentTaskId) =>
      tasks.values.cast<Task>().where((t) => t.parentTaskId == parentTaskId).toList();

  /// 可按番茄钟计时的任务（仅计时类）
  List<Task> getPomodoroTasks(String childId) => getTodayTasks(childId)
      .where((t) => t.needsPomodoro && !t.isDone)
      .toList();

  Future<void> saveTask(Task task) => tasks.put(task.id, task);

  Future<void> deleteTask(String taskId) async {
    await tasks.delete(taskId);
    // 级联删除子任务
    await _deleteWhere(tasks, (Task e) => e.parentTaskId == taskId);
  }

  /// 检查类任务：直接勾选完成，立即发放奖励
  Future<int> completeSimpleTask(Task task, {int? overrideReward}) async {
    final reward = overrideReward ?? task.rewardValue;
    await tasks.put(
      task.id,
      task.copyWith(
        status: TaskStatus.done,
        completedAt: DateTime.now(),
        lastCompletedAt: DateTime.now(),
      ),
    );
    if (reward > 0) {
      await changeCoin(task.childId, task.rewardType, reward);
    }
    return reward;
  }

  /// 撤销完成（重复任务次日重置时使用）
  Future<void> resetTask(Task task) async {
    await tasks.put(
      task.id,
      task.copyWith(
        status: TaskStatus.todo,
        startedAt: null,
        clearStartedAt: true,
        usedSeconds: 0,
        completedAt: null,
      ),
    );
  }

  // ==================== 习惯 ====================

  /// 某孩子的全部习惯（未归档）
  List<Habit> getHabits(String childId) =>
      habits.values.cast<Habit>().where((h) => h.childId == childId && !h.isArchived).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// 按日期获取当天已打卡的习惯 ID 集合
  Set<String> getCheckedHabitIdsOn(String childId, DateTime day) {
    final key = HabitCheckIn.keyOf(day);
    return checkIns.values
        .cast<HabitCheckIn>()
        .where((c) => c.childId == childId && c.dateKey == key)
        .map((c) => c.habitId)
        .toSet();
  }

  /// 获取某习惯最近 n 天的打卡情况（用于 7 格周视图）
  List<bool> getHabitWeekStatus(String habitId, String childId, {int days = 7}) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = now.subtract(Duration(days: days - 1 - i));
      final key = HabitCheckIn.keyOf(day);
      return checkIns.values.cast<HabitCheckIn>().any(
            (c) => c.habitId == habitId && c.childId == childId && c.dateKey == key,
          );
    });
  }

  /// 某习惯某天的打卡时间（用于展示星星牌上的时间）
  DateTime? getHabitCheckInTime(String habitId, String childId, DateTime day) {
    final key = HabitCheckIn.keyOf(day);
    for (final c in checkIns.values.cast<HabitCheckIn>()) {
      if (c.habitId == habitId && c.childId == childId && c.dateKey == key) {
        return c.checkInTime;
      }
    }
    return null;
  }

  Future<void> saveHabit(Habit habit) => habits.put(habit.id, habit);

  Future<void> deleteHabit(String habitId) async {
    await habits.delete(habitId);
    await _deleteWhere(checkIns, (HabitCheckIn e) => e.habitId == habitId);
  }

  /// 习惯打卡
  ///
  /// 返回本次发放的奖励数值（0 表示未发放，例如今日已打满次数）。
  /// 同时处理连击天数计算与连击目标奖励发放。
  Future<int> checkInHabit(Habit habit, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final dateKey = HabitCheckIn.keyOf(now);

    // 今日已打卡次数
    final todayCount = checkIns.values.cast<HabitCheckIn>().where(
          (c) => c.habitId == habit.id && c.dateKey == dateKey,
        ).length;
    if (todayCount >= habit.dailyTargetCount) return 0;

    // 写入打卡记录
    final record = HabitCheckIn(
      id: newId('ci_'),
      childId: habit.childId,
      habitId: habit.id,
      checkInTime: now,
      dateKey: dateKey,
    );
    await checkIns.put(record.id, record);

    // ---------- 连击天数计算 ----------
    var streak = habit.currentStreakDays;
    final last = habit.lastCheckInTime;
    if (last == null) {
      streak = 1;
    } else {
      final lastDay = DateTime(last.year, last.month, last.day);
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(lastDay).inDays;
      if (diff == 0) {
        // 当天再次打卡，连击不变
      } else if (diff == 1) {
        streak += 1;
      } else {
        // 断连，重新计数
        streak = 1;
      }
    }

    var updated = habit.copyWith(
      currentStreakDays: streak,
      bestStreakDays: streak > habit.bestStreakDays ? streak : habit.bestStreakDays,
      lastCheckInTime: now,
    );
    await habits.put(updated.id, updated);

    // 发放日常打卡奖励
    var reward = 0;
    if (habit.checkInRewardValue > 0 &&
        habit.checkInRewardType != RewardType.custom) {
      await changeCoin(habit.childId, habit.checkInRewardType, habit.checkInRewardValue);
      reward = habit.checkInRewardValue;
    }

    // 连击目标奖励
    if (updated.canClaimStreakReward && updated.targetRewardType != RewardType.custom) {
      await changeCoin(updated.childId, updated.targetRewardType, updated.targetRewardValue);
      updated = updated.copyWith(lastStreakRewardAt: now);
      await habits.put(updated.id, updated);
      reward += updated.targetRewardValue;
    }

    return reward;
  }

  // ==================== 兑换 ====================

  List<ExchangeLog> getExchangeLogs(String childId) => exchangeLogs.values
      .cast<ExchangeLog>()
      .where((e) => e.childId == childId)
      .toList()
    ..sort((a, b) => b.exchangeTime.compareTo(a.exchangeTime));

  Future<void> saveExchangeLog(ExchangeLog log) => exchangeLogs.put(log.id, log);

  /// 执行兑换：扣币 + 写入记录（状态为待审批）
  Future<ExchangeLog> performExchange({
    required String childId,
    required ShopItem item,
    required bool autoApprove,
  }) async {
    await changeCoin(childId, item.coinType, -item.price);
    final log = ExchangeLog(
      id: newId('ex_'),
      childId: childId,
      itemName: item.name,
      itemIcon: item.iconEmoji,
      coinType: item.coinType,
      costCoin: item.price,
      exchangeTime: DateTime.now(),
      status: autoApprove ? ExchangeStatus.done : ExchangeStatus.pending,
      shopItemId: item.id,
      approvedAt: autoApprove ? DateTime.now() : null,
    );
    await exchangeLogs.put(log.id, log);
    return log;
  }

  /// 家长审批兑换记录
  Future<void> approveExchange(String logId, bool approved) async {
    final log = exchangeLogs.get(logId) as ExchangeLog?;
    if (log == null) return;
    if (approved) {
      await exchangeLogs.put(
        logId,
        log.copyWith(status: ExchangeStatus.done, approvedAt: DateTime.now()),
      );
    } else {
      // 拒绝则退还所扣金币
      await changeCoin(log.childId, log.coinType, log.costCoin);
      await exchangeLogs.put(
        logId,
        log.copyWith(status: ExchangeStatus.rejected, approvedAt: DateTime.now()),
      );
    }
  }

  // ==================== 背包 ====================

  List<InventoryItem> getInventory(String childId) => inventory.values
      .cast<InventoryItem>()
      .where((i) => i.childId == childId)
      .toList();

  /// 购买商品入背包（已存在则累加数量）
  Future<void> addToInventory(String childId, ShopItem item) async {
    final existing = getInventory(childId)
        .where((i) => i.shopItemId == item.id && i.itemType == item.itemType)
        .toList();

    if (existing.isNotEmpty) {
      final it = existing.first;
      await inventory.put(it.id, it.copyWith(quantity: it.quantity + 1));
    } else {
      final it = InventoryItem(
        id: newId('inv_'),
        childId: childId,
        shopItemId: item.id,
        itemName: item.name,
        itemIcon: item.iconEmoji,
        itemType: item.itemType,
        quantity: 1,
        acquiredAt: DateTime.now(),
      );
      await inventory.put(it.id, it);
    }
  }

  // ==================== 番茄钟 ====================

  List<PomodoroSession> getPomodoroSessions(String childId) =>
      pomodoroSessions.values
          .cast<PomodoroSession>()
          .where((s) => s.childId == childId)
          .toList();

  Future<void> savePomodoroSession(PomodoroSession session) =>
      pomodoroSessions.put(session.id, session);

  /// 当日学习总时长（分钟，仅统计正常完成的番茄钟）
  int getTodayStudyMinutes(String childId, {DateTime? day}) {
    final key = HabitCheckIn.keyOf(day ?? DateTime.now());
    return getPomodoroSessions(childId)
        .where((s) => s.dateKey == key && s.isCompleted)
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }

  // ==================== 朗读录音 ====================

  /// 某孩子全部录音（按时间倒序，最新在前）
  List<Recording> getRecordings(String childId) {
    final list = recordings.values
        .cast<Recording>()
        .where((r) => r.childId == childId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 某孩子某天的录音（按时间正序，便于按时间线展示）
  List<Recording> getRecordingsOn(String childId, String dateKey) {
    final list =
        getRecordings(childId).where((r) => r.dateKey == dateKey).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// 某孩子绑定到指定习惯的录音
  List<Recording> getRecordingsForHabit(String habitId, String childId) =>
      getRecordings(childId).where((r) => r.habitId == habitId).toList();

  /// 今日录音条数
  int getTodayRecordingCount(String childId, {DateTime? day}) {
    final key = HabitCheckIn.keyOf(day ?? DateTime.now());
    return getRecordingsOn(childId, key).length;
  }

  /// 累计录音条数（含全部历史）
  int getTotalRecordingCount(String childId) => getRecordings(childId).length;

  /// 累计有效朗读分钟数（仅统计达到 [Recording.minValidDurationMs] 的录音）
  int getTotalReadingMinutes(String childId) {
    final ms = getRecordings(childId)
        .where((r) => r.isValidReading)
        .fold(0, (sum, r) => sum + r.durationMs);
    return ms ~/ 60000;
  }

  Future<void> saveRecording(Recording recording) =>
      recordings.put(recording.id, recording);

  Future<void> deleteRecording(String recordingId) =>
      recordings.delete(recordingId);

  // ==================== 成就进度 ====================

  /// 重算某孩子的全部勋章进度（幂等）
  ///
  /// 设计要点：
  /// - 以 [ChildAchievement] 为**派生数据**，全部由业务表实时推导，
  ///   避免各处埋点上锁导致的遗漏；
  /// - 只在新解锁时写库并回调 [onUnlock]（用于发放奖励 + 播报台词）；
  /// - 未达成的勋章仅在进度发生变化时写库，减少 Hive 写入。
  ///
  /// 返回本次**新解锁**的勋章定义列表（调用方可据此发奖励）。
  Future<List<AchievementDef>> refreshAchievements(
    String childId, {
    void Function(AchievementDef def, ChildAchievement progress)? onUnlock,
  }) async {
    final defs = achievementDefs.values.cast<AchievementDef>().toList();
    if (defs.isEmpty) return const [];

    // 已有进度行索引
    final existing = <String, ChildAchievement>{};
    for (final p in childAchievements.values.cast<ChildAchievement>()) {
      if (p.childId == childId) existing[p.achievementId] = p;
    }

    final newlyUnlocked = <AchievementDef>[];

    for (final def in defs) {
      final value = achievementProgressValue(childId, def);
      final prev = existing[def.id];

      final wasUnlocked = prev?.isUnlocked ?? false;
      final isNowUnlocked = value >= def.conditionValue && def.conditionValue > 0;

      final progress = (prev ??
              ChildAchievement(
                id: newId('ach_'),
                childId: childId,
                achievementId: def.id,
              ))
          .copyWith(
        currentProgress: value,
        isUnlocked: wasUnlocked || isNowUnlocked,
        unlockedAt: (wasUnlocked || isNowUnlocked)
            ? (prev?.unlockedAt ?? DateTime.now())
            : prev?.unlockedAt,
      );

      // 未解锁且进度未变 → 跳过写入
      final changed = prev == null ||
          prev.currentProgress != value ||
          prev.isUnlocked != progress.isUnlocked;
      if (!changed) continue;

      await childAchievements.put(progress.id, progress);

      if (isNowUnlocked && !wasUnlocked) {
        newlyUnlocked.add(def);
        onUnlock?.call(def, progress);
      }
    }

    return newlyUnlocked;
  }

  /// 计算某勋章当前进度值（按 [AchievementDef.conditionType] 分派）
  int achievementProgressValue(String childId, AchievementDef def) {
    switch (def.conditionType) {
      case AchievementConditionType.totalTaskDone:
        return tasks.values
            .cast<Task>()
            .where((t) => t.childId == childId && t.isDone)
            .length;

      case AchievementConditionType.totalCheckIn:
        return checkIns.values
            .cast<HabitCheckIn>()
            .where((c) => c.childId == childId)
            .length;

      case AchievementConditionType.maxHabitStreak:
        final streaks = habits.values
            .cast<Habit>()
            .where((h) => h.childId == childId)
            .map((h) => h.bestStreakDays)
            .toList();
        return streaks.isEmpty
            ? 0
            : streaks.reduce((a, b) => a > b ? a : b);

      case AchievementConditionType.totalPomodoro:
        return pomodoroSessions.values
            .cast<PomodoroSession>()
            .where((s) => s.childId == childId && s.isCompleted)
            .length;

      case AchievementConditionType.totalStudyMinutes:
        return pomodoroSessions.values
            .cast<PomodoroSession>()
            .where((s) => s.childId == childId && s.isCompleted)
            .fold(0, (sum, s) => sum + s.actualMinutes);

      case AchievementConditionType.totalExchange:
        return exchangeLogs.values
            .cast<ExchangeLog>()
            .where((e) => e.childId == childId)
            .length;

      case AchievementConditionType.maxPetLevel:
        final levels = pets.values
            .cast<Pet>()
            .where((p) => p.childId == childId)
            .map((p) => p.level)
            .toList();
        return levels.isEmpty ? 0 : levels.reduce((a, b) => a > b ? a : b);

      case AchievementConditionType.usageDays:
        return _usageDaysOf(childId);

      case AchievementConditionType.totalRecording:
        return getTotalRecordingCount(childId);

      case AchievementConditionType.totalReadingMinutes:
        return getTotalReadingMinutes(childId);

      default:
        return 0;
    }
  }

  /// 使用天数：所有业务表中出现过的最早日期 → 今天，跨自然日计数（含首日）
  int _usageDaysOf(String childId) {
    DateTime? earliest;
    void consider(DateTime? dt) {
      if (dt == null) return;
      if (earliest == null || dt.isBefore(earliest!)) earliest = dt;
    }

    for (final t in tasks.values.cast<Task>()) {
      if (t.childId != childId) continue;
      consider(t.createdAt);
      consider(t.completedAt);
    }
    for (final h in habits.values.cast<Habit>()) {
      if (h.childId != childId) continue;
      consider(h.startDate);
      consider(h.lastCheckInTime);
    }
    for (final c in checkIns.values.cast<HabitCheckIn>()) {
      if (c.childId != childId) continue;
      consider(c.checkInTime);
    }
    for (final s in pomodoroSessions.values.cast<PomodoroSession>()) {
      if (s.childId != childId) continue;
      consider(s.startTime);
    }
    for (final r in recordings.values.cast<Recording>()) {
      if (r.childId != childId) continue;
      consider(r.createdAt);
    }

    if (earliest == null) return 0;
    final a = DateTime(earliest!.year, earliest!.month, earliest!.day);
    final now = DateTime.now();
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays + 1;
  }

  // ==================== 家长 PIN ====================

  /// 生成随机盐值
  String generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// 计算 PIN 哈希（SHA-256，salt + pin 拼接）
  String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt::$pin');
    return sha256.convert(bytes).toString();
  }

  /// 设置家长 PIN（首次设置或修改）
  Future<void> setParentPin(String pin) async {
    final s = getSettings();
    final salt = generateSalt();
    await saveSettings(
      s.copyWith(
        parentPinSalt: salt,
        parentPinHash: hashPin(pin, salt),
        hasSetPin: true,
      ),
    );
  }

  /// 校验家长 PIN
  bool verifyParentPin(String pin) {
    final s = getSettings();
    if (!s.hasSetPin) return false;
    return hashPin(pin, s.parentPinSalt) == s.parentPinHash;
  }

  // ==================== 种子数据 ====================

  /// 首次启动时注入全局配置数据
  ///
  /// 只在对应 Box 为空时注入，不会覆盖用户数据。
  Future<void> seedIfNeeded() async {
    if (achievementDefs.isEmpty) await _seedAchievements();
    if (shopItems.isEmpty) await _seedShopItems();
    if (habitTemplates.isEmpty) await _seedHabitTemplates();
    if (petDialogues.isEmpty) await _seedPetDialogues();
  }

  Future<void> _seedAchievements() async {
    final list = <AchievementDef>[
      // ---------- 成长 ----------
      AchievementDef(
        id: 'ach_growth_1', name: '初次见面', description: '完成首次任务',
        category: AchievementCategory.growth, iconEmoji: '🌱',
        conditionType: AchievementConditionType.totalTaskDone,
        conditionValue: 1, rewardValue: 20, sortOrder: 1,
      ),
      AchievementDef(
        id: 'ach_growth_2', name: '坚持一周', description: '连续使用 App 7 天',
        category: AchievementCategory.growth, iconEmoji: '📅',
        conditionType: AchievementConditionType.usageDays,
        conditionValue: 7, rewardValue: 50, sortOrder: 2,
      ),
      AchievementDef(
        id: 'ach_growth_3', name: '朝夕相处', description: '连续使用 App 30 天',
        category: AchievementCategory.growth, iconEmoji: '🌟',
        conditionType: AchievementConditionType.usageDays,
        conditionValue: 30, rewardValue: 200, sortOrder: 3,
      ),
      // ---------- 习惯 ----------
      AchievementDef(
        id: 'ach_habit_1', name: '小小习惯家', description: '累计打卡 10 次',
        category: AchievementCategory.habit, iconEmoji: '✅',
        conditionType: AchievementConditionType.totalCheckIn,
        conditionValue: 10, rewardValue: 30, sortOrder: 1,
      ),
      AchievementDef(
        id: 'ach_habit_2', name: '连击达人', description: '习惯连击达到 7 天',
        category: AchievementCategory.habit, iconEmoji: '🔥',
        conditionType: AchievementConditionType.maxHabitStreak,
        conditionValue: 7, rewardValue: 60, sortOrder: 2,
      ),
      AchievementDef(
        id: 'ach_habit_3', name: '钢铁意志', description: '习惯连击达到 30 天',
        category: AchievementCategory.habit, iconEmoji: '💎',
        conditionType: AchievementConditionType.maxHabitStreak,
        conditionValue: 30, rewardValue: 250, sortOrder: 3,
      ),
      // ---------- 效率 ----------
      AchievementDef(
        id: 'ach_eff_1', name: '专注新手', description: '完成 5 个番茄钟',
        category: AchievementCategory.efficiency, iconEmoji: '⏱️',
        conditionType: AchievementConditionType.totalPomodoro,
        conditionValue: 5, rewardValue: 30, sortOrder: 1,
      ),
      AchievementDef(
        id: 'ach_eff_2', name: '专注高手', description: '完成 50 个番茄钟',
        category: AchievementCategory.efficiency, iconEmoji: '⚡',
        conditionType: AchievementConditionType.totalPomodoro,
        conditionValue: 50, rewardValue: 150, sortOrder: 2,
      ),
      AchievementDef(
        id: 'ach_eff_3', name: '时间管理师', description: '累计学习 600 分钟',
        category: AchievementCategory.efficiency, iconEmoji: '🏆',
        conditionType: AchievementConditionType.totalStudyMinutes,
        conditionValue: 600, rewardValue: 200, sortOrder: 3,
      ),
      // ---------- 知识 ----------
      AchievementDef(
        id: 'ach_know_1', name: '博览群书', description: '累计完成任务 20 个',
        category: AchievementCategory.knowledge, iconEmoji: '📚',
        conditionType: AchievementConditionType.totalTaskDone,
        conditionValue: 20, rewardValue: 80, sortOrder: 1,
      ),
      AchievementDef(
        id: 'ach_know_2', name: '百炼成钢', description: '累计完成任务 100 个',
        category: AchievementCategory.knowledge, iconEmoji: '🎓',
        conditionType: AchievementConditionType.totalTaskDone,
        conditionValue: 100, rewardValue: 300, sortOrder: 2,
      ),
      // ---------- 知识 · 朗读打卡 ----------
      AchievementDef(
        id: 'ach_read_1', name: '小小朗读者', description: '完成首次朗读录音',
        category: AchievementCategory.knowledge, iconEmoji: '🎤',
        conditionType: AchievementConditionType.totalRecording,
        conditionValue: 1, rewardValue: 20, sortOrder: 3,
      ),
      AchievementDef(
        id: 'ach_read_2', name: '朗读小达人', description: '累计朗读 20 次',
        category: AchievementCategory.knowledge, iconEmoji: '🔊',
        conditionType: AchievementConditionType.totalRecording,
        conditionValue: 20, rewardValue: 120, sortOrder: 4,
      ),
      AchievementDef(
        id: 'ach_read_3', name: '金话筒', description: '累计朗读 60 分钟',
        category: AchievementCategory.knowledge, iconEmoji: '🏅',
        conditionType: AchievementConditionType.totalReadingMinutes,
        conditionValue: 60, rewardValue: 280, sortOrder: 5,
      ),
    ];
    for (final a in list) {
      await achievementDefs.put(a.id, a);
    }
  }

  Future<void> _seedShopItems() async {
    final list = <ShopItem>[
      // ---------- 心愿商店（消耗心愿币，兑换现实奖励） ----------
      ShopItem(
        id: 'wish_game', name: '玩游戏', iconEmoji: '🎮', shopType: ShopType.wish,
        itemType: ShopItemType.reality, price: 50, coinType: RewardType.wishCoin,
        specLabel: '30分钟', sortOrder: 1,
      ),
      ShopItem(
        id: 'wish_tv', name: '看电视', iconEmoji: '📺', shopType: ShopType.wish,
        itemType: ShopItemType.reality, price: 40, coinType: RewardType.wishCoin,
        specLabel: '30分钟', sortOrder: 2,
      ),
      ShopItem(
        id: 'wish_snack', name: '吃零食', iconEmoji: '🍪', shopType: ShopType.wish,
        itemType: ShopItemType.reality, price: 20, coinType: RewardType.wishCoin,
        specLabel: '一次', sortOrder: 3,
      ),
      ShopItem(
        id: 'wish_money', name: '零花钱', iconEmoji: '💰', shopType: ShopType.wish,
        itemType: ShopItemType.reality, price: 100, coinType: RewardType.wishCoin,
        specLabel: '10元', sortOrder: 4,
      ),
      ShopItem(
        id: 'wish_park', name: '去公园', iconEmoji: '🎡', shopType: ShopType.wish,
        itemType: ShopItemType.reality, price: 80, coinType: RewardType.wishCoin,
        specLabel: '1小时', sortOrder: 5,
      ),
      ShopItem(
        id: 'wish_book', name: '买新书', iconEmoji: '📖', shopType: ShopType.wish,
        itemType: ShopItemType.reality, price: 150, coinType: RewardType.wishCoin,
        specLabel: '一本', sortOrder: 6,
      ),
      // ---------- 怪兽商店（消耗宠物币，买食物/皮肤/道具） ----------
      ShopItem(
        id: 'pet_apple', name: '红苹果', iconEmoji: '🍎', shopType: ShopType.monster,
        itemType: ShopItemType.food, price: 10, coinType: RewardType.petCoin,
        specLabel: '饱食度+25', unlockLevel: 1, sortOrder: 1,
      ),
      ShopItem(
        id: 'pet_cake', name: '小蛋糕', iconEmoji: '🍰', shopType: ShopType.monster,
        itemType: ShopItemType.food, price: 25, coinType: RewardType.petCoin,
        specLabel: '饱食度+40', unlockLevel: 2, sortOrder: 2,
      ),
      ShopItem(
        id: 'pet_milk', name: '牛奶', iconEmoji: '🥛', shopType: ShopType.monster,
        itemType: ShopItemType.food, price: 15, coinType: RewardType.petCoin,
        specLabel: '心情+10', unlockLevel: 1, sortOrder: 3,
      ),
      ShopItem(
        id: 'skin_rainbow', name: '彩虹皮肤', iconEmoji: '🌈', shopType: ShopType.monster,
        itemType: ShopItemType.skin, price: 120, coinType: RewardType.petCoin,
        specLabel: '限定外观', unlockLevel: 10, sortOrder: 4,
      ),
      ShopItem(
        id: 'skin_star', name: '星空皮肤', iconEmoji: '✨', shopType: ShopType.monster,
        itemType: ShopItemType.skin, price: 100, coinType: RewardType.petCoin,
        specLabel: '限定外观', unlockLevel: 10, sortOrder: 5,
      ),
      ShopItem(
        id: 'prop_ball', name: '小皮球', iconEmoji: '⚽', shopType: ShopType.monster,
        itemType: ShopItemType.prop, price: 60, coinType: RewardType.petCoin,
        specLabel: '互动道具', unlockLevel: 15, sortOrder: 6,
      ),
    ];
    for (final s in list) {
      await shopItems.put(s.id, s);
    }
  }

  Future<void> _seedHabitTemplates() async {
    final list = <HabitTemplate>[
      // ---------- 学习 ----------
      HabitTemplate(id: 'ht_zaodu', name: '早读', category: HabitCategory.study,
          iconEmoji: '📖', defaultRewardValue: 10, sortOrder: 1),
      HabitTemplate(id: 'ht_gushi', name: '背古诗', category: HabitCategory.study,
          iconEmoji: '📜', defaultRewardValue: 10, sortOrder: 2),
      HabitTemplate(id: 'ht_kewai', name: '课外阅读', category: HabitCategory.study,
          iconEmoji: '📚', defaultRewardValue: 15, sortOrder: 3),
      HabitTemplate(id: 'ht_jiancha', name: '检查作业', category: HabitCategory.study,
          iconEmoji: '🔍', defaultRewardValue: 10, sortOrder: 4),
      HabitTemplate(id: 'ht_yuxi', name: '预习新课', category: HabitCategory.study,
          iconEmoji: '✏️', defaultRewardValue: 15, sortOrder: 5),
      HabitTemplate(id: 'ht_fuxi', name: '复习巩固', category: HabitCategory.study,
          iconEmoji: '🔁', defaultRewardValue: 15, sortOrder: 6),
      HabitTemplate(id: 'ht_cuoti', name: '错题整理', category: HabitCategory.study,
          iconEmoji: '📕', defaultRewardValue: 15, sortOrder: 7),
      HabitTemplate(id: 'ht_kousuan', name: '口算练习', category: HabitCategory.study,
          iconEmoji: '🔢', defaultRewardValue: 10, sortOrder: 8),
      HabitTemplate(id: 'ht_english', name: '英语打卡', category: HabitCategory.study,
          iconEmoji: '🔤', defaultRewardValue: 10, sortOrder: 9),
      HabitTemplate(id: 'ht_wangke', name: '完成网课', category: HabitCategory.study,
          iconEmoji: '💻', defaultRewardValue: 20, sortOrder: 10),
      HabitTemplate(id: 'ht_jilu', name: '记录作业', category: HabitCategory.study,
          iconEmoji: '📝', defaultRewardValue: 5, sortOrder: 11),
      HabitTemplate(id: 'ht_shuxie', name: '书写工整', category: HabitCategory.study,
          iconEmoji: '🖊️', defaultRewardValue: 10, sortOrder: 12),
      HabitTemplate(id: 'ht_zhuanzhu', name: '专注学习', category: HabitCategory.study,
          iconEmoji: '🎯', defaultRewardValue: 15, sortOrder: 13),
      HabitTemplate(id: 'ht_chengji', name: '成绩提升', category: HabitCategory.study,
          iconEmoji: '📈', defaultRewardValue: 30, sortOrder: 14),
      HabitTemplate(id: 'ht_duli', name: '独立思考', category: HabitCategory.study,
          iconEmoji: '💡', defaultRewardValue: 15, sortOrder: 15),
      // ---------- 健康 ----------
      HabitTemplate(id: 'ht_zaoshui', name: '早睡', category: HabitCategory.health,
          iconEmoji: '🛏️', defaultRewardValue: 15, sortOrder: 1),
      HabitTemplate(id: 'ht_zaoqi', name: '早起', category: HabitCategory.health,
          iconEmoji: '🌅', defaultRewardValue: 15, sortOrder: 2),
      HabitTemplate(id: 'ht_shuaya', name: '认真刷牙', category: HabitCategory.health,
          iconEmoji: '🦷', defaultRewardValue: 5, sortOrder: 3),
      HabitTemplate(id: 'ht_heshui', name: '多喝水', category: HabitCategory.health,
          iconEmoji: '💧', defaultRewardValue: 5, sortOrder: 4),
      HabitTemplate(id: 'ht_duanlian', name: '锻炼', category: HabitCategory.health,
          iconEmoji: '🏋️', defaultRewardValue: 15, sortOrder: 5),
      HabitTemplate(id: 'ht_tiaosheng', name: '跳绳', category: HabitCategory.health,
          iconEmoji: '🪢', defaultRewardValue: 10, sortOrder: 6),
      HabitTemplate(id: 'ht_paobu', name: '跑步', category: HabitCategory.health,
          iconEmoji: '🏃', defaultRewardValue: 15, sortOrder: 7),
      HabitTemplate(id: 'ht_yuantiao', name: '远眺', category: HabitCategory.health,
          iconEmoji: '👀', defaultRewardValue: 5, sortOrder: 8),
      HabitTemplate(id: 'ht_junheng', name: '均衡饮食', category: HabitCategory.health,
          iconEmoji: '🥗', defaultRewardValue: 10, sortOrder: 9),
      HabitTemplate(id: 'ht_zuozi', name: '坐姿端正', category: HabitCategory.health,
          iconEmoji: '🪑', defaultRewardValue: 5, sortOrder: 10),
      HabitTemplate(id: 'ht_huwai', name: '户外运动', category: HabitCategory.health,
          iconEmoji: '⛰️', defaultRewardValue: 15, sortOrder: 11),
      HabitTemplate(id: 'ht_lingshi', name: '少吃零食', category: HabitCategory.health,
          iconEmoji: '🚫', defaultRewardValue: 10, sortOrder: 12),
      // ---------- 生活 ----------
      HabitTemplate(id: 'ht_shuzhuo', name: '整理书桌', category: HabitCategory.life,
          iconEmoji: '🗄️', defaultRewardValue: 10, sortOrder: 1),
      HabitTemplate(id: 'ht_shubao', name: '整理书包', category: HabitCategory.life,
          iconEmoji: '🎒', defaultRewardValue: 10, sortOrder: 2),
      HabitTemplate(id: 'ht_wanju', name: '收拾玩具', category: HabitCategory.life,
          iconEmoji: '🧸', defaultRewardValue: 10, sortOrder: 3),
      HabitTemplate(id: 'ht_beizi', name: '叠被子', category: HabitCategory.life,
          iconEmoji: '🛌', defaultRewardValue: 10, sortOrder: 4),
      HabitTemplate(id: 'ht_wan', name: '帮忙洗碗', category: HabitCategory.life,
          iconEmoji: '🍽️', defaultRewardValue: 15, sortOrder: 5),
      HabitTemplate(id: 'ht_yifu', name: '帮忙洗衣服', category: HabitCategory.life,
          iconEmoji: '🧺', defaultRewardValue: 15, sortOrder: 6),
      HabitTemplate(id: 'ht_zuofan', name: '帮忙做饭', category: HabitCategory.life,
          iconEmoji: '🍳', defaultRewardValue: 20, sortOrder: 7),
      HabitTemplate(id: 'ht_dadi', name: '帮忙扫地', category: HabitCategory.life,
          iconEmoji: '🧹', defaultRewardValue: 15, sortOrder: 8),
      HabitTemplate(id: 'ht_tuola', name: '不拖拉', category: HabitCategory.life,
          iconEmoji: '⏰', defaultRewardValue: 15, sortOrder: 9),
      HabitTemplate(id: 'ht_qingxu', name: '情绪稳定', category: HabitCategory.life,
          iconEmoji: '😌', defaultRewardValue: 15, sortOrder: 10),
      HabitTemplate(id: 'ht_shoushi', name: '守时', category: HabitCategory.life,
          iconEmoji: '⌚', defaultRewardValue: 15, sortOrder: 11),
      HabitTemplate(id: 'ht_zijishangxue', name: '自己上学', category: HabitCategory.life,
          iconEmoji: '🏫', defaultRewardValue: 20, sortOrder: 12),
      // ---------- 兴趣 ----------
      HabitTemplate(id: 'ht_lanqiu', name: '篮球', category: HabitCategory.interest,
          iconEmoji: '🏀', defaultRewardValue: 15, sortOrder: 1),
      HabitTemplate(id: 'ht_pingpong', name: '乒乓', category: HabitCategory.interest,
          iconEmoji: '🏓', defaultRewardValue: 15, sortOrder: 2),
      HabitTemplate(id: 'ht_zuqiu', name: '足球', category: HabitCategory.interest,
          iconEmoji: '⚽', defaultRewardValue: 15, sortOrder: 3),
      HabitTemplate(id: 'ht_youyong', name: '游泳', category: HabitCategory.interest,
          iconEmoji: '🏊', defaultRewardValue: 20, sortOrder: 4),
      HabitTemplate(id: 'ht_shufa', name: '书法', category: HabitCategory.interest,
          iconEmoji: '🖌️', defaultRewardValue: 15, sortOrder: 5),
      HabitTemplate(id: 'ht_biancheng', name: '编程', category: HabitCategory.interest,
          iconEmoji: '💻', defaultRewardValue: 20, sortOrder: 6),
      HabitTemplate(id: 'ht_weiqi', name: '围棋', category: HabitCategory.interest,
          iconEmoji: '⚫', defaultRewardValue: 15, sortOrder: 7),
      HabitTemplate(id: 'ht_tiaowu', name: '跳舞', category: HabitCategory.interest,
          iconEmoji: '💃', defaultRewardValue: 15, sortOrder: 8),
      HabitTemplate(id: 'ht_jiewu', name: '街舞', category: HabitCategory.interest,
          iconEmoji: '🕺', defaultRewardValue: 15, sortOrder: 9),
      HabitTemplate(id: 'ht_gangqin', name: '钢琴', category: HabitCategory.interest,
          iconEmoji: '🎹', defaultRewardValue: 20, sortOrder: 10),
      HabitTemplate(id: 'ht_jita', name: '吉他', category: HabitCategory.interest,
          iconEmoji: '🎸', defaultRewardValue: 20, sortOrder: 11),
      HabitTemplate(id: 'ht_jiazigu', name: '架子鼓', category: HabitCategory.interest,
          iconEmoji: '🥁', defaultRewardValue: 20, sortOrder: 12),
    ];
    for (final t in list) {
      await habitTemplates.put(t.id, t);
    }
  }

  Future<void> _seedPetDialogues() async {
    final list = <PetDialogue>[
      // 长时间未打开（对应截图：两天没见，本怪兽有点想乐乐～）
      PetDialogue(id: 'dl_absent_1', text: '{days}天没见，本怪兽有点想{name}～',
          triggerType: PetDialogueTrigger.longAbsence, priority: 100),
      PetDialogue(id: 'dl_absent_2', text: '你终于回来啦！我都快无聊死啦～',
          triggerType: PetDialogueTrigger.longAbsence, priority: 100),
      PetDialogue(id: 'dl_absent_3', text: '好久不见，{name}有没有想我呀？',
          triggerType: PetDialogueTrigger.longAbsence, priority: 100),
      // 闲时随机
      PetDialogue(id: 'dl_idle_1', text: '今天想先做哪件事呀？', priority: 10),
      PetDialogue(id: 'dl_idle_2', text: '一起加油，我陪着你哦～', priority: 10),
      PetDialogue(id: 'dl_idle_3', text: '完成任务就能换好吃的啦！', priority: 10),
      PetDialogue(id: 'dl_idle_4', text: '要不要来一个番茄钟？', priority: 10),
      PetDialogue(id: 'dl_idle_5', text: '我一直在这里陪着你呢～', priority: 10),
      // 各情绪状态
      PetDialogue(id: 'dl_hungry', text: '肚子咕咕叫了，好想吃东西～',
          moodState: PetMoodState.hungry, priority: 50),
      PetDialogue(id: 'dl_sleepy', text: '有点困了…陪我玩一会儿好吗？',
          moodState: PetMoodState.sleepy, priority: 50),
      PetDialogue(id: 'dl_sad', text: '我有点不开心，抱抱我嘛～',
          moodState: PetMoodState.sad, priority: 60),
      PetDialogue(id: 'dl_happy', text: '今天心情超好的！',
          moodState: PetMoodState.happy, priority: 40),
      // 番茄钟完成
      PetDialogue(id: 'dl_pomo_ok', text: '哇！你太棒啦，专注了这么久！',
          triggerType: PetDialogueTrigger.pomodoroDone, priority: 80),
      PetDialogue(id: 'dl_pomo_ok2', text: '好厉害！这是给你的奖励～',
          triggerType: PetDialogueTrigger.pomodoroDone, priority: 80),
      // 番茄钟作废（对应需求：宠物垂头丧气）
      PetDialogue(id: 'dl_pomo_fail', text: '呜…本次任务失败了，下次要专心哦',
          triggerType: PetDialogueTrigger.pomodoroFailed, priority: 90),
      PetDialogue(id: 'dl_pomo_fail2', text: '有点小失落…我们下次再努力好吗？',
          triggerType: PetDialogueTrigger.pomodoroFailed, priority: 90),
      // 兑换余额不足（对应需求：心愿币还差一点点哦～）
      PetDialogue(id: 'dl_no_coin', text: '心愿币还差一点点哦～再攒攒就有了！',
          triggerType: PetDialogueTrigger.coinNotEnough, priority: 90),
      PetDialogue(id: 'dl_no_coin2', text: '呜呜，心愿币不够呢，我们再努力一下～',
          triggerType: PetDialogueTrigger.coinNotEnough, priority: 90),
      // 兑换成功
      PetDialogue(id: 'dl_ex_ok', text: '兑换成功！好好享受吧～',
          triggerType: PetDialogueTrigger.exchangeDone, priority: 80),
      // 打卡成功
      PetDialogue(id: 'dl_ci_ok', text: '打卡成功！坚持就是胜利～',
          triggerType: PetDialogueTrigger.checkInDone, priority: 70),
      // 升级
      PetDialogue(id: 'dl_levelup', text: '我升级啦！变得更厉害了呢！',
          triggerType: PetDialogueTrigger.levelUp, priority: 100),
      // 朗读打卡（复用 checkInDone 触发器，优先级低于普通打卡以保证先播常规台词）
      PetDialogue(id: 'dl_read_ok_1', text: '哇，你读得真好听！我都听入迷啦～',
          triggerType: PetDialogueTrigger.checkInDone, priority: 68),
      PetDialogue(id: 'dl_read_ok_2', text: '朗读完成！声音越来越有感情了呢～',
          triggerType: PetDialogueTrigger.checkInDone, priority: 66),
    ];
    for (final d in list) {
      await petDialogues.put(d.id, d);
    }
  }

  // ==================== 宠物台词选取 ====================

  /// 根据触发场景与宠物状态挑选一条台词
  ///
  /// [days] 用于「多日未见」类台词的占位符替换。
  String pickDialogue({
    required String trigger,
    PetMoodState? moodState,
    String name = '小朋友',
    int days = 0,
  }) {
    var candidates = petDialogues.values.cast<PetDialogue>().where(
          (d) => d.triggerType == trigger,
        ).toList();

    // 场景台词找不到时，回退到闲时台词
    if (candidates.isEmpty && trigger != PetDialogueTrigger.idle) {
      candidates = petDialogues.values
          .cast<PetDialogue>()
          .where((d) => d.triggerType == PetDialogueTrigger.idle)
          .toList();
    }

    // 优先匹配情绪
    if (moodState != null && trigger == PetDialogueTrigger.idle) {
      final matched = candidates.where((d) => d.moodState == moodState).toList();
      if (matched.isNotEmpty) candidates = matched;
    }

    if (candidates.isEmpty) return '今天也要加油哦～';

    candidates.sort((a, b) => b.priority.compareTo(a.priority));
    final pick = candidates[_random.nextInt(candidates.length)];

    return pick.text
        .replaceAll('{days}', days.toString())
        .replaceAll('{name}', name);
  }
}
