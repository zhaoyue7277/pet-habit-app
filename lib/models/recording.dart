import 'dart:typed_data';

import 'package:hive/hive.dart';

import 'habit.dart';

/// 朗读录音记录（多孩隔离：通过 [childId] 关联 Child）
///
/// 对应需求模块：朗读打卡。孩子点击「开始朗读」录制一段音频，
/// 与某个习惯打卡绑定，家长可在打卡日记中回放。
///
/// 存储策略：
/// - 音频字节（AAC / m4a 或 Web 端 audio/webm）以 `Uint8List` 存入 [bytes]，
///   与记录同生命周期，删除记录即释放音频，不会残留孤儿文件；
/// - 单条录音上限 [maxDurationMs]（3 分钟），AAC 64kbps 下约 1.4MB，
///   远低于 Hive 单值安全阈值。
///
/// ⚠️ typeId 15 为**首次分配**，`@HiveField` 编号一旦发布不可变更，只能在末尾追加。
@HiveType(typeId: 15)
class Recording extends HiveObject {
  Recording({
    required this.id,
    required this.childId,
    this.habitId,
    required this.dateKey,
    required this.durationMs,
    required this.bytes,
    this.mimeType = 'audio/mp4',
    this.label = '',
    required this.createdAt,
  });

  @HiveField(0)
  String id;

  /// 外键 → Child.id
  @HiveField(1)
  String childId;

  /// 关联的习惯 id（可空：允许脱离习惯的纯朗读录音）
  @HiveField(2)
  String? habitId;

  /// 日期键 `yyyy-MM-dd`（复用 [HabitCheckIn.keyOf] 生成，保证与打卡口径一致）
  @HiveField(3)
  String dateKey;

  /// 录音时长（毫秒），用于列表展示与「朗读满 X 秒才计数」的判定
  @HiveField(4)
  int durationMs;

  /// 音频字节。手写 adapter 中按 `Uint8List` 原样读写。
  @HiveField(5)
  Uint8List bytes;

  /// 音频 MIME 类型：Android 端 `audio/mp4`，Web 端 `audio/webm`
  @HiveField(6)
  String mimeType;

  /// 录音标签 / 标题（如「朗读《静夜思》」，可空字符串表示未命名）
  @HiveField(7)
  String label;

  /// 录制时间
  @HiveField(8)
  DateTime createdAt;

  /// 单条录音时长上限：3 分钟
  static const int maxDurationMs = 3 * 60 * 1000;

  /// 「有效朗读」最短时长：3 秒（过短视为误触，不计入激励）
  static const int minValidDurationMs = 3000;

  /// 时长展示：`0:07` / `1:23`
  String get durationLabel {
    final totalSec = (durationMs / 1000).round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 是否达到「有效朗读」门槛
  bool get isValidReading => durationMs >= minValidDurationMs;

  /// 归属日期（与 [HabitCheckIn.keyOf] 同口径）
  static String keyOf(DateTime dt) => HabitCheckIn.keyOf(dt);

  Recording copyWith({
    String? id,
    String? childId,
    String? habitId,
    String? dateKey,
    int? durationMs,
    Uint8List? bytes,
    String? mimeType,
    String? label,
    DateTime? createdAt,
  }) {
    return Recording(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      habitId: habitId ?? this.habitId,
      dateKey: dateKey ?? this.dateKey,
      durationMs: durationMs ?? this.durationMs,
      bytes: bytes ?? this.bytes,
      mimeType: mimeType ?? this.mimeType,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
