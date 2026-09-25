import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import 'core_providers.dart';

/// 当前孩子的全部宠物
final petListProvider = Provider<List<Pet>>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return [];
  // 读取时先做衰减结算，保证数值准确
  return ref.watch(databaseProvider).getPets(childId);
});

/// 当前出战宠物
final activePetProvider = Provider<Pet?>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  ref.watch(dataRevisionProvider);
  if (childId == null) return null;
  return ref.watch(databaseProvider).getActivePet(childId);
});

/// 宠物界面所需的实时状态（含衰减后的饱食度 / 心情）
class PetLiveState {
  const PetLiveState({
    required this.pet,
    required this.satiety,
    required this.mood,
    required this.moodState,
    required this.dialogue,
  });

  final Pet pet;

  /// 实时饱食度（已按时间衰减计算）
  final int satiety;

  /// 实时心情值
  final int mood;

  /// 当前情绪状态
  final PetMoodState moodState;

  /// 当前展示的台词
  final String dialogue;

  double get satietyRatio => satiety / 100;

  double get moodRatio => mood / 100;

  double get expProgress => pet.expProgress;

  int get expToNext => Pet.expToNextLevel(pet.level);
}

/// 宠物实时状态 Provider
///
/// **核心设计：** 饱食度 / 心情属于「计算型数据」，
/// 每次读取都基于 [Pet.lastDecayTime] 实时计算，
/// 而不是靠定时任务去改数据库——那样 App 未打开时数值会算错。
final petLiveStateProvider = Provider<PetLiveState?>((ref) {
  final pet = ref.watch(activePetProvider);
  final child = ref.watch(activeChildProvider);
  if (pet == null) return null;

  final now = DateTime.now();
  final satiety = pet.currentSatiety(now);
  final mood = pet.currentMood(now);
  final state = pet.moodState(now);

  final db = ref.watch(databaseProvider);
  final dialogue = db.pickDialogue(
    trigger: PetDialogueTrigger.idle,
    moodState: state,
    name: child?.name ?? '小朋友',
  );

  return PetLiveState(
    pet: pet,
    satiety: satiety,
    mood: mood,
    moodState: state,
    dialogue: dialogue,
  );
});

/// 宠物操作控制器
class PetController {
  PetController(this._db, this._ref);

  final DatabaseService _db;
  final Ref _ref;

  void _bump() => _ref.read(dataRevisionProvider.notifier).bump();

  /// 领养宠物
  Future<Pet> adoptPet({
    required String childId,
    required PetSpecies species,
    String name = '',
  }) async {
    final existing = _db.getPets(childId);
    final pet = Pet(
      id: _db.newId('pet_'),
      childId: childId,
      species: species,
      name: name,
      isBattle: existing.isEmpty, // 第一只自动出战
      lastDecayTime: DateTime.now(),
      createdAt: DateTime.now(),
    );
    await _db.savePet(pet);

    final child = _db.children.get(childId) as Child?;
    if (child != null && existing.isEmpty) {
      await _db.saveChild(child.copyWith(currentPetId: pet.id));
    }
    _bump();
    return pet;
  }

  /// 切换出战宠物（等级 / 经验 / 皮肤各自独立，互不影响）
  Future<void> switchPet(String childId, String petId) async {
    await _db.switchPet(childId, petId);
    _bump();
  }

  /// 喂食（消耗背包食物）
  Future<FeedResult> feed(Pet pet, InventoryItem food) async {
    final before = pet.level;
    final ok = await _db.feedPet(pet.id, food);
    if (!ok) return const FeedResult(success: false);

    final after = _db.pets.get(pet.id) as Pet?;
    _bump();
    return FeedResult(
      success: true,
      leveledUp: after != null && after.level > before,
      newLevel: after?.level ?? before,
    );
  }

  /// 抚摸（提升心情）
  Future<void> caress(Pet pet) async {
    await _db.petPet(pet.id);
    _bump();
  }

  /// 结算衰减（进入宠物页或互动前调用，把实时值固化）
  Future<void> settle(Pet pet) async {
    await _db.settlePet(pet);
    _bump();
  }
}

/// 喂食结果
class FeedResult {
  const FeedResult({
    required this.success,
    this.leveledUp = false,
    this.newLevel = 1,
  });

  final bool success;
  final bool leveledUp;
  final int newLevel;
}

final petControllerProvider = Provider<PetController>((ref) {
  return PetController(ref.watch(databaseProvider), ref);
});
