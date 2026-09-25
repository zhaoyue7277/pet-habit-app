import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';
import 'adapters.dart';

/// Hive 初始化器
///
/// **为什么手写 TypeAdapter 而不用 build_runner 生成？**
/// 代码生成需要你本地执行 `flutter pub run build_runner build`，
/// 手写适配器可以让工程「拿到即跑」，不依赖额外生成步骤，
/// 同时也更便于迁移鸿蒙时逐个排查序列化逻辑。
class HiveInit {
  HiveInit._();

  // ==================== Box 名称常量 ====================
  static const String boxChildren = 'children';
  static const String boxPets = 'pets';
  static const String boxTasks = 'tasks';
  static const String boxHabits = 'habits';
  static const String boxCheckIns = 'check_ins';
  static const String boxExchangeLogs = 'exchange_logs';
  static const String boxAchievementDefs = 'achievement_defs';
  static const String boxChildAchievements = 'child_achievements';
  static const String boxShopItems = 'shop_items';
  static const String boxInventory = 'inventory';
  static const String boxHabitTemplates = 'habit_templates';
  static const String boxPetDialogues = 'pet_dialogues';
  static const String boxDailyNotes = 'daily_notes';
  static const String boxPomodoroSessions = 'pomodoro_sessions';
  static const String boxRecordings = 'recordings';
  static const String boxSettings = 'settings';

  /// 需要打开的普通 Box 列表
  static const List<String> allBoxes = [
    boxChildren,
    boxPets,
    boxTasks,
    boxHabits,
    boxCheckIns,
    boxExchangeLogs,
    boxAchievementDefs,
    boxChildAchievements,
    boxShopItems,
    boxInventory,
    boxHabitTemplates,
    boxPetDialogues,
    boxDailyNotes,
    boxPomodoroSessions,
    boxRecordings,
  ];

  /// 初始化 Hive 并注册全部适配器
  static Future<void> init() async {
    await Hive.initFlutter();

    // ---------- 注册 TypeAdapter（typeId 必须与 Model 注解一致） ----------
    Hive
      ..registerAdapter(ChildAdapter())                    // 0
      ..registerAdapter(PetAdapter())                      // 1
      ..registerAdapter(TaskAdapter())                     // 2
      ..registerAdapter(HabitAdapter())                    // 3
      ..registerAdapter(HabitCheckInAdapter())             // 4
      ..registerAdapter(ExchangeLogAdapter())              // 5
      ..registerAdapter(AchievementDefAdapter())           // 6
      ..registerAdapter(ChildAchievementAdapter())         // 7
      ..registerAdapter(ShopItemAdapter())                 // 8
      ..registerAdapter(InventoryItemAdapter())            // 9
      ..registerAdapter(HabitTemplateAdapter())            // 10
      ..registerAdapter(PetDialogueAdapter())              // 11
      ..registerAdapter(DailyNoteAdapter())                // 12
      ..registerAdapter(PomodoroSessionAdapter())          // 13
      ..registerAdapter(AppSettingsAdapter())              // 14
      ..registerAdapter(RecordingAdapter());               // 15

    // ---------- 打开所有 Box ----------
    for (final name in allBoxes) {
      await Hive.openBox(name);
    }
    // 设置表使用独立 Box，取第一个实例
    if (!Hive.isBoxOpen(boxSettings)) {
      await Hive.openBox<AppSettings>(boxSettings);
    }
  }

  /// 关闭全部 Box（App 退出或测试时使用）
  static Future<void> closeAll() async {
    await Hive.close();
  }
}
