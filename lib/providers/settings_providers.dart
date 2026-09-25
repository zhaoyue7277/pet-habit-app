import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import 'core_providers.dart';

/// 全局设置
final settingsProvider = Provider<AppSettings>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(databaseProvider).getSettings();
});

/// 设置操作控制器
class SettingsController {
  SettingsController(this._db, this._ref);

  final DatabaseService _db;
  final Ref _ref;

  void _bump() => _ref.read(dataRevisionProvider.notifier).bump();

  /// 保存设置
  Future<void> save(AppSettings settings) async {
    await _db.saveSettings(settings);
    _bump();
  }

  /// 更新番茄钟时长
  Future<void> setPomodoroMinutes(int minutes) async {
    await _db.saveSettings(_db.getSettings().copyWith(defaultPomodoroMinutes: minutes));
    _bump();
  }

  /// 更新允许切出的宽限时间（分钟）
  Future<void> setAllowAbandonMinutes(int minutes) async {
    await _db.saveSettings(_db.getSettings().copyWith(allowAbandonMinutes: minutes));
    _bump();
  }

  /// 设置白噪音音量
  Future<void> setWhiteNoiseVolume(double volume) async {
    await _db.saveSettings(_db.getSettings().copyWith(whiteNoiseVolume: volume));
    _bump();
  }

  /// 记录上次打开时间（用于「多日未见」台词判断）
  Future<void> touchLastOpenTime() async {
    await _db.saveSettings(_db.getSettings().copyWith(lastOpenTime: DateTime.now()));
  }
}

final settingsControllerProvider = Provider<SettingsController>((ref) {
  return SettingsController(ref.watch(databaseProvider), ref);
});

// ===================================================================
// 成就勋章
// ===================================================================

/// 勋章墙数据（按分类分组，含孩子解锁进度）
class AchievementView {
  const AchievementView({
    required this.def,
    required this.progress,
  });

  final AchievementDef def;
  final ChildAchievement progress;

  bool get isUnlocked => progress.isUnlocked;

  /// 进度 0.0 - 1.0
  double get ratio {
    if (def.conditionValue <= 0) return 0;
    return (progress.currentProgress / def.conditionValue).clamp(0.0, 1.0);
  }

  String get progressLabel =>
      '${progress.currentProgress.clamp(0, def.conditionValue)}/${def.conditionValue}';
}

/// 某个分类下的勋章列表
final achievementsByCategoryProvider =
    Provider.family<List<AchievementView>, AchievementCategory>((ref, category) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return [];

  final db = ref.watch(databaseProvider);
  final defs = db.achievementDefs.values
      .cast<AchievementDef>()
      .where((d) => d.category == category)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  final progressMap = <String, ChildAchievement>{};
  for (final p in db.childAchievements.values.cast<ChildAchievement>()) {
    if (p.childId == childId) progressMap[p.achievementId] = p;
  }

  return defs.map((def) {
    final progress = progressMap[def.id] ??
        ChildAchievement(
          id: '',
          childId: childId,
          achievementId: def.id,
        );
    return AchievementView(def: def, progress: progress);
  }).toList();
});

/// 已解锁勋章总数
final unlockedAchievementCountProvider = Provider<int>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return 0;
  final db = ref.watch(databaseProvider);
  return db.childAchievements.values
      .cast<ChildAchievement>()
      .where((p) => p.childId == childId && p.isUnlocked)
      .length;
});

/// 全部勋章总数
final totalAchievementCountProvider = Provider<int>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(databaseProvider).achievementDefs.length;
});

// ===================================================================
// 打卡日记 / 家长 Note
// ===================================================================

/// 某天的家长备注
final dailyNoteProvider =
    Provider.family<DailyNote?, String>((ref, dateKey) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return null;

  final db = ref.watch(databaseProvider);
  for (final n in db.dailyNotes.values.cast<DailyNote>()) {
    if (n.childId == childId && n.dateKey == dateKey) return n;
  }
  return null;
});

/// 日记控制器
class DiaryController {
  DiaryController(this._db, this._ref);

  final DatabaseService _db;
  final Ref _ref;

  void _bump() => _ref.read(dataRevisionProvider.notifier).bump();

  /// 保存家长备注（存在则更新，不存在则新建）
  Future<void> saveNote({
    required String childId,
    required String dateKey,
    required String content,
    String moodEmoji = '😊',
  }) async {
    DailyNote? existing;
    for (final n in _db.dailyNotes.values.cast<DailyNote>()) {
      if (n.childId == childId && n.dateKey == dateKey) {
        existing = n;
        break;
      }
    }

    if (existing != null) {
      await _db.dailyNotes.put(
        existing.id,
        existing.copyWith(
          content: content,
          moodEmoji: moodEmoji,
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      final note = DailyNote(
        id: _db.newId('note_'),
        childId: childId,
        dateKey: dateKey,
        content: content,
        moodEmoji: moodEmoji,
        updatedAt: DateTime.now(),
      );
      await _db.dailyNotes.put(note.id, note);
    }
    _bump();
  }
}

final diaryControllerProvider = Provider<DiaryController>((ref) {
  return DiaryController(ref.watch(databaseProvider), ref);
});
