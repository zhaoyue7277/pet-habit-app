import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import 'core_providers.dart';

// ===================================================================
// 朗读录音 Providers
// ===================================================================

/// 某孩子全部录音（最新在前）
final recordingsProvider = Provider<List<Recording>>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return const [];
  return ref.watch(databaseProvider).getRecordings(childId);
});

/// 某天的录音（dateKey 为 `yyyy-MM-dd`）
final recordingsOnProvider =
    Provider.family<List<Recording>, String>((ref, dateKey) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return const [];
  return ref.watch(databaseProvider).getRecordingsOn(childId, dateKey);
});

/// 今日录音条数
final todayRecordingCountProvider = Provider<int>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return 0;
  return ref.watch(databaseProvider).getTodayRecordingCount(childId);
});

/// 录音控制器
class RecordingController {
  RecordingController(this._db, this._ref);

  final DatabaseService _db;
  final Ref _ref;

  void _bump() => _ref.read(dataRevisionProvider.notifier).bump();

  /// 新增一条录音
  ///
  /// [rewardWishCoin] / [rewardExp] 为本次朗读的激励，由调用方按语义传入
  /// （默认与一次习惯打卡等价：+1 心愿币 / +5 经验）。
  /// 仅在录音达到 [Recording.minValidDurationMs] 时才发放，避免误触刷奖励。
  Future<Recording> addRecording({
    required String childId,
    String? habitId,
    required Uint8List bytes,
    required int durationMs,
    String mimeType = 'audio/mp4',
    String label = '',
    DateTime? at,
    int rewardWishCoin = 1,
    int rewardExp = 5,
  }) async {
    final now = at ?? DateTime.now();
    final recording = Recording(
      id: _db.newId('rec_'),
      childId: childId,
      habitId: habitId,
      dateKey: Recording.keyOf(now),
      durationMs: durationMs,
      bytes: bytes,
      mimeType: mimeType,
      label: label,
      createdAt: now,
    );

    await _db.saveRecording(recording);

    // 激励：仅有效朗读发放
    if (recording.isValidReading) {
      if (rewardWishCoin != 0) {
        await _db.changeCoin(childId, RewardType.wishCoin, rewardWishCoin);
      }
      if (habitId != null && rewardExp != 0) {
        final pets = _db.getPets(childId);
        if (pets.isNotEmpty) {
          await _db.addPetExp(pets.first.id, rewardExp);
        }
      }
    }

    // 录音会影响「朗读打卡」类勋章进度
    await _db.refreshAchievements(childId);

    _bump();
    return recording;
  }

  Future<void> deleteRecording(String recordingId) async {
    await _db.deleteRecording(recordingId);
    _bump();
  }

  /// 某天录音总时长（毫秒）
  int totalDurationOn(String childId, String dateKey) => _db
      .getRecordingsOn(childId, dateKey)
      .fold(0, (sum, r) => sum + r.durationMs);
}

final recordingControllerProvider = Provider<RecordingController>((ref) {
  return RecordingController(ref.watch(databaseProvider), ref);
});
