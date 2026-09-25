import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/pet_providers.dart';
import '../providers/shop_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import '../widgets/pet_avatar.dart';

/// 宠物中心页面
///
/// **对应需求模块 4：**
/// - 支持切换宠物（解锁过的），不同宠物有独立的等级、经验、皮肤
/// - 等级解锁规则：1级喂食/抚摸，2级宠物商店，5级进化，10级时装，15级特殊互动
/// - 互动：点击转圈或跳跃，喂食消耗宠物币提升饱食度，抚摸提升心情
/// - 升级播放闪光特效
class PetCenterPage extends ConsumerStatefulWidget {
  const PetCenterPage({super.key});

  @override
  ConsumerState<PetCenterPage> createState() => _PetCenterPageState();
}

class _PetCenterPageState extends ConsumerState<PetCenterPage> {
  bool _jumping = false;
  bool _spinning = false;
  bool _glowing = false;

  /// 触发点击互动动画（随机跳跃或转圈）
  void _triggerInteractionAnimation() {
    if (_jumping || _spinning) return;
    if (DateTime.now().millisecond.isEven) {
      setState(() => _jumping = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _jumping = false);
      });
    } else {
      setState(() => _spinning = true);
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted) setState(() => _spinning = false);
      });
    }
  }

  /// 播放升级闪光
  void _playGlow() {
    setState(() => _glowing = true);
    Future.delayed(AppSizes.durationCelebrate, () {
      if (mounted) setState(() => _glowing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(petLiveStateProvider);
    final pets = ref.watch(petListProvider);

    if (live == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('宠物中心'),
        ),
        body: EmptyPlaceholder(
          emoji: '🐣',
          text: '还没有宠物',
          hint: '领养一只陪你一起成长吧',
          action: BouncyButton(
            onPressed: _showAdoptSheet,
            width: 200,
            child: const Text('领养宠物'),
          ),
        ),
      );
    }

    final pet = live.pet;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('宠物中心'),
        actions: [
          // 切换宠物按钮
          if (pets.length > 1)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: () => _showPetSwitcher(pets),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _showAdoptSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          children: [
            // ---------- 宠物形象区 ----------
            _buildPetStage(live),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 状态数值 ----------
            _buildStatusCard(live),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 互动按钮 ----------
            _buildInteractionButtons(pet),

            const SizedBox(height: AppSizes.spaceLg),

            // ---------- 能力解锁进度 ----------
            _buildAbilityCard(pet),

            const SizedBox(height: AppSizes.spaceXxl),
          ],
        ),
      ),
    );
  }

  /// 宠物形象展示区
  Widget _buildPetStage(PetLiveState live) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceXl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.skyGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        children: [
          // 宠物名与等级
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                live.pet.displayName,
                style: const TextStyle(
                  fontSize: AppSizes.fontTitle,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              TagChip(
                text: 'Lv.${live.pet.level}',
                color: AppColors.secondary,
                textColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceLg),

          // 宠物形象（点击互动）
          GestureDetector(
            onTap: () {
              _triggerInteractionAnimation();
              ref.read(petControllerProvider).caress(live.pet);
            },
            child: PetAvatar(
              pet: live.pet,
              size: AppSizes.petCenterSize,
              moodState: live.moodState,
              isJumping: _jumping,
              isSpinning: _spinning,
              showGlow: _glowing,
            ),
          ),
          const SizedBox(height: AppSizes.spaceMd),

          // 台词
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceXl),
            child: Text(
              live.dialogue,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontLabel,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 状态数值卡（经验 / 饱食度 / 心情）
  Widget _buildStatusCard(PetLiveState live) {
    return AppCard(
      child: Column(
        children: [
          // 经验条
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: AppSizes.spaceSm),
              const Text(
                '经验',
                style: TextStyle(
                  fontSize: AppSizes.fontLabel,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSizes.spaceMd),
              Expanded(
                child: AppProgressBar(
                  value: live.expProgress,
                  color: AppColors.secondary,
                  height: 12,
                ),
              ),
              const SizedBox(width: AppSizes.spaceMd),
              Text(
                '${live.pet.exp}/${live.expToNext}',
                style: const TextStyle(
                  fontSize: AppSizes.fontCaption,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceLg),

          // 饱食度
          _statusRow(
            emoji: '🍚',
            label: '饱食度',
            value: live.satiety,
            color: live.satiety < 30 ? AppColors.error : AppColors.success,
          ),
          const SizedBox(height: AppSizes.spaceMd),

          // 心情值
          _statusRow(
            emoji: '❤️',
            label: '心情值',
            value: live.mood,
            color: live.mood < 30 ? AppColors.error : AppColors.secondary,
          ),
          const SizedBox(height: AppSizes.spaceMd),

          // 状态描述
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSizes.spaceSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Center(
              child: Text(
                '当前状态：${live.moodState.emoji} ${live.moodState.label}',
                style: const TextStyle(
                  fontSize: AppSizes.fontLabel,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required String emoji,
    required String label,
    required int value,
    required Color color,
  }) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: AppSizes.spaceSm),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppSizes.fontLabel,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: AppProgressBar(
            value: value / 100,
            color: color,
            height: 12,
          ),
        ),
        const SizedBox(width: AppSizes.spaceMd),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: AppSizes.fontLabel,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// 互动按钮区
  Widget _buildInteractionButtons(Pet pet) {
    return Row(
      children: [
        // 喂食
        Expanded(
          child: _actionButton(
            emoji: '🍎',
            label: '喂食',
            enabled: pet.hasAbility(PetAbility.feed),
            onTap: () => _showFeedSheet(pet),
          ),
        ),
        const SizedBox(width: AppSizes.spaceMd),

        // 抚摸
        Expanded(
          child: _actionButton(
            emoji: '🤚',
            label: '抚摸',
            enabled: pet.hasAbility(PetAbility.pet),
            onTap: () => _caressPet(pet),
          ),
        ),
        const SizedBox(width: AppSizes.spaceMd),

        // 宠物商店
        Expanded(
          child: _actionButton(
            emoji: '🏪',
            label: '商店',
            enabled: pet.hasAbility(PetAbility.shop),
            lockedHint: 'Lv.${PetAbility.shop.unlockLevel}',
            onTap: () => _toast('请到「商店」页面购买宠物用品'),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String emoji,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    String? lockedHint,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : () => _toast('需要 ${lockedHint ?? ''} 解锁哦'),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceLg),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surface : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: enabled
                ? Border.all(color: AppColors.primaryLight, width: 2)
                : null,
            boxShadow: enabled ? AppShadows.card : null,
          ),
          child: Column(
            children: [
              Text(
                enabled ? emoji : '🔒',
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(height: AppSizes.spaceXs),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppSizes.fontLabel,
                  fontWeight: FontWeight.w700,
                  color: enabled ? AppColors.textPrimary : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 能力解锁进度卡
  Widget _buildAbilityCard(Pet pet) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '解锁进度',
            style: TextStyle(
              fontSize: AppSizes.fontHeadline,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceLg),
          ...PetAbility.values.map((ability) {
            final unlocked = pet.hasAbility(ability);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: unlocked
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unlocked ? '✅' : '🔒',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceMd),
                  Expanded(
                    child: Text(
                      ability.label,
                      style: TextStyle(
                        fontSize: AppSizes.fontBody,
                        fontWeight: FontWeight.w600,
                        color: unlocked
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                  Text(
                    'Lv.${ability.unlockLevel}',
                    style: TextStyle(
                      fontSize: AppSizes.fontLabel,
                      fontWeight: FontWeight.w700,
                      color: unlocked
                          ? AppColors.success
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== 交互 ====================

  /// 抚摸
  Future<void> _caressPet(Pet pet) async {
    await ref.read(petControllerProvider).caress(pet);
    _triggerInteractionAnimation();
  }

  /// 喂食面板
  void _showFeedSheet(Pet pet) {
    final foods = ref.read(inventoryFoodProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(AppSizes.spaceLg),
        padding: const EdgeInsets.all(AppSizes.spaceXl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '选择食物',
              style: TextStyle(
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLg),

            if (foods.isEmpty)
              const EmptyPlaceholder(
                emoji: '🍽️',
                text: '背包里还没有食物',
                hint: '去怪兽商店买一些吧～',
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: foods.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.spaceSm),
                  itemBuilder: (_, i) {
                    final food = foods[i];
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _feedPet(pet, food);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppSizes.spaceLg),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Text(food.itemIcon,
                                style: const TextStyle(fontSize: 30)),
                            const SizedBox(width: AppSizes.spaceMd),
                            Expanded(
                              child: Text(
                                food.itemName,
                                style: const TextStyle(
                                  fontSize: AppSizes.fontBody,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            TagChip(
                              text: '×${food.quantity}',
                              color: AppColors.primaryLight,
                              textColor: AppColors.primaryDark,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 执行喂食
  Future<void> _feedPet(Pet pet, InventoryItem food) async {
    final result = await ref.read(petControllerProvider).feed(pet, food);

    if (!mounted) return;

    if (!result.success) {
      _toast('喂食失败，请稍后再试');
      return;
    }

    // 升级播放闪光特效
    if (result.leveledUp) {
      _playGlow();
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => _LevelUpDialog(newLevel: result.newLevel),
        );
      }
    } else {
      _toast('${pet.displayName} 吃得很开心～');
    }
  }

  /// 切换宠物
  void _showPetSwitcher(List<Pet> pets) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(AppSizes.spaceLg),
        padding: const EdgeInsets.all(AppSizes.spaceXl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '切换宠物',
              style: TextStyle(
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceXs),
            const Text(
              '每只宠物的等级、经验和皮肤都是独立的哦',
              style: TextStyle(
                fontSize: AppSizes.fontCaption,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLg),

            ...pets.map((p) {
              final isActive = p.isBattle;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
                child: GestureDetector(
                  onTap: () async {
                    await ref
                        .read(petControllerProvider)
                        .switchPet(p.childId, p.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.spaceMd),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: isActive
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        PetAvatar(pet: p, size: 56),
                        const SizedBox(width: AppSizes.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.displayName,
                                style: const TextStyle(
                                  fontSize: AppSizes.fontBody,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Lv.${p.level} · ${p.species.label}',
                                style: const TextStyle(
                                  fontSize: AppSizes.fontCaption,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          const TagChip(
                            text: '出战中',
                            color: AppColors.success,
                            textColor: Colors.white,
                            fontSize: AppSizes.fontTiny,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 领养新宠物
  void _showAdoptSheet() {
    final child = ref.read(activeChildProvider);
    if (child == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(AppSizes.spaceLg),
        padding: const EdgeInsets.all(AppSizes.spaceXl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '领养新宠物',
              style: TextStyle(
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceLg),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: AppSizes.spaceMd,
                crossAxisSpacing: AppSizes.spaceMd,
              ),
              itemCount: PetSpecies.values.length,
              itemBuilder: (context, i) {
                final species = PetSpecies.values[i];
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(petControllerProvider).adoptPet(
                          childId: child.id,
                          species: species,
                        );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Color(species.bodyColorValue)
                              .withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('🐾',
                            style: TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(height: AppSizes.spaceXs),
                      Text(
                        species.label,
                        style: const TextStyle(
                          fontSize: AppSizes.fontCaption,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: AppSizes.fontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }
}

/// 升级庆祝弹窗
class _LevelUpDialog extends StatelessWidget {
  const _LevelUpDialog({required this.newLevel});

  final int newLevel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppSizes.spaceMd),
            const Text(
              '升级啦！',
              style: TextStyle(
                fontSize: AppSizes.fontTitle,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spaceXl,
                vertical: AppSizes.spaceSm,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE08A), Color(0xFFF5B942)],
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
              ),
              child: Text(
                'Lv.$newLevel',
                style: const TextStyle(
                  fontSize: AppSizes.fontTitle,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spaceLg),

            // 新解锁能力提示
            ...PetAbility.values
                .where((a) => a.unlockLevel == newLevel)
                .map((a) => Text(
                      '🎉 解锁新能力：${a.label}',
                      style: const TextStyle(
                        fontSize: AppSizes.fontBody,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    )),

            const SizedBox(height: AppSizes.spaceXl),
            BouncyButton(
              onPressed: () => Navigator.pop(context),
              width: 180,
              child: const Text('太棒啦'),
            ),
          ],
        ),
      ),
    );
  }
}
