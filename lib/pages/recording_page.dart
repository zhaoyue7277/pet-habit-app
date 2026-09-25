import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/habit_providers.dart';
import '../providers/pet_providers.dart';
import '../providers/recording_providers.dart';
import '../routes/app_router.dart';
import '../services/recording_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../widgets/common_widgets.dart';
import '../widgets/pet_avatar.dart';

/// 朗读录音页
///
/// 流程：进入 → 点大圆键开始录音 → 波形 + 计时 + 宠物「听书」动画
///      → 再次点击停止 → 回放试听 → 保存到日记 / 重录。
///
/// 激励：有效朗读（≥ [Recording.minValidDurationMs]）计 1 次朗读打卡，
/// 发放心愿币 + 宠物经验，并推进「小小朗读者」系列勋章。
///
/// 便捷入口：[habit] 非空时表示由某个习惯的打卡流程进入，
/// 保存后会一并完成该习惯的当日打卡（口语朗读类习惯的常用路径）。
class RecordingPage extends ConsumerStatefulWidget {
  const RecordingPage({super.key, this.habit});

  /// 关联的习惯（可空：纯朗读录音，不绑定打卡）
  final Habit? habit;

  @override
  ConsumerState<RecordingPage> createState() => _RecordingPageState();
}

enum _Phase { idle, recording, preview, saving }

class _RecordingPageState extends ConsumerState<RecordingPage>
    with TickerProviderStateMixin {
  final RecordingService _service = RecordingService.instance;

  _Phase _phase = _Phase.idle;
  String? _error;
  RecordedAudio? _result;

  /// 实际录音时长（毫秒），用于展示与存储
  int _durationMs = 0;

  /// 宠物聆听脉冲动画
  late final AnimationController _pulseCtrl;

  Timer? _ticker;

  /// 音量采样缓冲（每 300ms 采一次，最多保留 60 个）
  final List<double> _levelsBuffer = <double>[];
  int _amplitudeTick = 0;

  /// 试听状态
  bool _playing = false;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _completeSub = _service.onPlaybackComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _completeSub?.cancel();
    _pulseCtrl.dispose();
    _service.stopPlayback();
    super.dispose();
  }

  // ==================== 交互 ====================

  Future<void> _toggleRecord() async {
    if (_phase == _Phase.recording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    // 从试听态切回录音前先停播放
    await _service.stopPlayback();
    if (mounted) setState(() => _playing = false);

    final err = await _service.start(
      maxDurationMs: Recording.maxDurationMs,
      onAutoStop: () {
        if (mounted && _phase == _Phase.recording) _stopRecording();
      },
    );

    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _error = null;
      _phase = _Phase.recording;
      _durationMs = 0;
      _result = null;
    });

    // 计时器：驱动时长显示（100ms 粒度，足够平滑）
    _ticker?.cancel();
    _levelsBuffer.clear();
    _amplitudeTick = 0;
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _durationMs = _service.elapsed.inMilliseconds);
      // 每 3 个 tick（300ms）采一次音量，驱动波形
      _amplitudeTick++;
      if (_amplitudeTick % 3 == 0) _sampleAmplitude();
    });
  }

  /// 采样当前音量，推入波形缓冲
  Future<void> _sampleAmplitude() async {
    final level = await _service.currentAmplitude();
    if (!mounted) return;
    setState(() {
      _levelsBuffer.add(level);
      // 缓冲上限，避免长时间录音导致列表无界增长
      if (_levelsBuffer.length > 60) {
        _levelsBuffer.removeRange(0, _levelsBuffer.length - 60);
      }
    });
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _ticker = null;

    final audio = await _service.stop();
    if (!mounted) return;

    if (audio == null || audio.bytes.isEmpty) {
      setState(() {
        _phase = _Phase.idle;
        _durationMs = 0;
        _error = '没有录到声音，再试一次吧～';
      });
      return;
    }

    setState(() {
      _phase = _Phase.preview;
      _result = audio;
      _durationMs = audio.durationMs;
      _error = null;
    });
  }

  Future<void> _discardAndRetry() async {
    await _service.stopPlayback();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _result = null;
      _durationMs = 0;
      _playing = false;
      _error = null;
    });
  }

  Future<void> _preview() async {
    final audio = _result;
    if (audio == null) return;

    if (_playing) {
      await _service.stopPlayback();
      if (mounted) setState(() => _playing = false);
      return;
    }

    final ok = await _service.playBytes(audio.bytes, mimeType: audio.mimeType);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = '试听失败，可能是音频格式不受支持');
      return;
    }
    setState(() => _playing = true);
  }

  Future<void> _save() async {
    final audio = _result;
    final childId = ref.read(activeChildIdProvider);
    if (audio == null || childId == null) return;

    setState(() {
      _phase = _Phase.saving;
      _error = null;
    });

    await _service.stopPlayback();

    final habit = widget.habit;
    final controller = ref.read(recordingControllerProvider);

    await controller.addRecording(
      childId: childId,
      habitId: habit?.id,
      bytes: audio.bytes,
      durationMs: audio.durationMs,
      mimeType: audio.mimeType,
      label: habit != null ? '朗读·${habit.name}' : '自由朗读',
    );

    // 若由习惯打卡流程进入，保存录音即视为完成当日打卡
    int checkInReward = 0;
    if (habit != null) {
      checkInReward = await ref.read(habitControllerProvider).checkIn(habit);
    }

    if (!mounted) return;

    final valid = audio.durationMs >= Recording.minValidDurationMs;
    final parts = <String>[];
    if (valid) parts.add('💛 +1');
    if (habit != null && checkInReward > 0) {
      parts.add('${habit.checkInRewardType.emoji} +$checkInReward');
    }

    // ⚠️ 先取 messenger 再 pop：pop 之后当前 route 的 Scaffold 被销毁，
    // 若此时才 ScaffoldMessenger.of(context) 可能拿到失效上下文，
    // SnackBar 会不显示（或抛异常）。
    final messenger = ScaffoldMessenger.of(context);
    AppNavigator.pop(context, true);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          parts.isEmpty
              ? '录音已保存，下次多读一会儿吧～'
              : '朗读完成！获得 ${parts.join('  ')}',
          style: const TextStyle(
            fontSize: AppSizes.fontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: valid ? AppColors.success : AppColors.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);
    final pet = ref.watch(activePetProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('朗读打卡'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.spaceLg),
          child: Column(
            children: [
              if (widget.habit != null) _buildHabitBanner(),
              const SizedBox(height: AppSizes.spaceLg),
              _buildPetStage(pet),
              const SizedBox(height: AppSizes.spaceLg),
              _buildTimer(),
              const SizedBox(height: AppSizes.spaceLg),
              _buildWaveform(),
              const SizedBox(height: AppSizes.spaceXl),
              _buildMainButton(),
              const SizedBox(height: AppSizes.spaceMd),
              _buildHint(),
              if (_error != null) ...[
                const SizedBox(height: AppSizes.spaceLg),
                _buildError(),
              ],
              if (_phase == _Phase.preview) ...[
                const SizedBox(height: AppSizes.spaceXl),
                _buildPreviewActions(child?.name ?? '小朋友'),
              ],
              const SizedBox(height: AppSizes.spaceXxl),
            ],
          ),
        ),
      ),
    );
  }

  /// 关联习惯提示条
  Widget _buildHabitBanner() {
    final habit = widget.habit!;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceLg,
        vertical: AppSizes.spaceMd,
      ),
      child: Row(
        children: [
          Text(habit.iconEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: AppSizes.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '本次朗读将完成习惯打卡',
                  style: TextStyle(
                    fontSize: AppSizes.fontCaption,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppSizes.fontLabel,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          TagChip(
            text: '${habit.checkInRewardType.emoji}+${habit.checkInRewardValue}',
            color: AppColors.accent,
            textColor: AppColors.accentDark,
          ),
        ],
      ),
    );
  }

  /// 宠物「听书」舞台：录音时张嘴聆听 + 声波扩散
  Widget _buildPetStage(Pet? pet) {
    final recording = _phase == _Phase.recording;
    return SizedBox(
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (recording)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                final t = _pulseCtrl.value;
                return Container(
                  width: 120 + t * 78,
                  height: 120 + t * 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.12 * (1 - t)),
                  ),
                );
              },
            ),
          PetAvatar(
            pet: pet,
            size: 124,
            moodState: recording ? PetMoodState.happy : PetMoodState.normal,
          ),
          if (recording)
            Positioned(
              right: 24,
              top: 26,
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, _) => Opacity(
                  opacity: 0.4 + _pulseCtrl.value * 0.6,
                  child: const Text('🎧', style: TextStyle(fontSize: 26)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 计时 / 状态文案
  Widget _buildTimer() {
    final recording = _phase == _Phase.recording;
    final sec = _durationMs / 1000;
    final over = _durationMs >= Recording.minValidDurationMs;

    final text = switch (_phase) {
      _Phase.idle => '准备好了就开始吧',
      _Phase.recording => _fmt(_durationMs),
      _Phase.preview => _fmt(_durationMs),
      _Phase.saving => '正在保存…',
    };

    return Column(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: recording ? AppSizes.fontDisplay : AppSizes.fontHeadline,
            fontWeight: FontWeight.w700,
            color: recording
                ? (over ? AppColors.success : AppColors.primary)
                : AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (recording) ...[
          const SizedBox(height: AppSizes.spaceXs),
          Text(
            over ? '很棒！可以停下来保存啦' : '再多读一会儿，满 3 秒就算有效哦',
            style: const TextStyle(
              fontSize: AppSizes.fontCaption,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (_phase == _Phase.preview) ...[
          const SizedBox(height: AppSizes.spaceXs),
          Text(
            sec >= 3 ? '这段朗读很棒！' : '有点短，建议重录一次',
            style: TextStyle(
              fontSize: AppSizes.fontCaption,
              color: sec >= 3 ? AppColors.success : AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  /// 波形（录音时跟随真实音量起伏，静止时灰条）
  Widget _buildWaveform() {
    const count = 28;
    final recording = _phase == _Phase.recording;

    // 历史音量序列：最近 count 个采样，形成向右流动的波形
    final levels = _waveformLevels;

    return SizedBox(
      height: 56,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(count, (i) {
              final level = i < levels.length ? levels[i] : 0.0;
              // 静止时保持一条低矮的灰带，避免空白
              final amp = recording
                  ? (0.12 + level * 0.88)
                  : 0.16 + (i % 3) * 0.03;
              return Container(
                width: 3.2,
                height: 8 + amp * 40,
                margin: const EdgeInsets.symmetric(horizontal: 1.8),
                decoration: BoxDecoration(
                  color: recording
                      ? Color.lerp(AppColors.primary, AppColors.accent, i / count)!
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  /// 最近 28 次音量采样（0.0 - 1.0）
  List<double> get _waveformLevels {
    final all = _levelsBuffer;
    if (all.length <= 28) return all;
    return all.sublist(all.length - 28);
  }

  /// 主按钮：大圆键
  Widget _buildMainButton() {
    if (_phase == _Phase.preview || _phase == _Phase.saving) {
      return const SizedBox(height: 8);
    }

    final recording = _phase == _Phase.recording;
    return GestureDetector(
      onTap: _phase == _Phase.saving ? null : _toggleRecord,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, _) {
          final scale = recording ? 1 + _pulseCtrl.value * 0.06 : 1.0;
          return Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: AppSizes.durationFast,
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: recording
                    ? const LinearGradient(
                        colors: [Color(0xFFFF9A8B), Color(0xFFE76F51)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : AppColors.primaryGradient,
                boxShadow: AppShadows.fab,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    recording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 42,
                    color: AppColors.textOnPrimary,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recording ? '停止' : '开始朗读',
                    style: const TextStyle(
                      fontSize: AppSizes.fontCaption,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 辅助提示
  Widget _buildHint() {
    final hint = switch (_phase) {
      _Phase.idle => '找一个安静的地方，大声读出来吧～',
      _Phase.recording => '最长可录 3 分钟',
      _Phase.preview => '试听一下，满意就保存到日记',
      _Phase.saving => '稍等一下…',
    };
    return Text(
      hint,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: AppSizes.fontCaption,
        color: AppColors.textHint,
      ),
    );
  }

  /// 错误提示
  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: AppSizes.spaceSm),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: AppSizes.fontCaption,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 预览操作：重录 / 试听 / 保存
  Widget _buildPreviewActions(String childName) {
    final playing = _playing;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: BouncyButton(
                height: AppSizes.buttonSmallHeight,
                color: AppColors.surfaceVariant,
                onPressed: _discardAndRetry,
                child: const Text(
                  '重录',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.spaceMd),
            Expanded(
              child: BouncyButton(
                height: AppSizes.buttonSmallHeight,
                color: AppColors.secondary,
                onPressed: _preview,
                child: Text(playing ? '⏸ 停止' : '▶ 试听'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceMd),
        BouncyButton(
          width: double.infinity,
          onPressed: _save,
          child: Text('保存到 $childName 的日记 📖'),
        ),
      ],
    );
  }

  static String _fmt(int ms) {
    final totalSec = (ms / 1000).floor();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
