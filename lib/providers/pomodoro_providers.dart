import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import 'core_providers.dart';

/// 番茄钟运行状态
enum PomodoroStatus {
  idle('未开始'),
  running('专注中'),
  paused('已暂停'),
  finished('已完成'),
  aborted('已作废');

  const PomodoroStatus(this.label);
  final String label;
}

/// 番茄钟状态
class PomodoroState {
  const PomodoroState({
    this.status = PomodoroStatus.idle,
    this.taskId,
    this.taskTitle = '',
    this.planMinutes = 25,
    this.remainingSeconds = 25 * 60,
    this.whiteNoiseType,
    this.whiteNoiseOn = false,
    this.lastAbandonReason = '',
    this.pendingExitAt,
  });

  /// 当前状态
  final PomodoroStatus status;

  /// 关联任务 ID
  final String? taskId;

  /// 任务标题（用于界面展示）
  final String taskTitle;

  /// 计划时长（分钟）
  final int planMinutes;

  /// 剩余秒数
  final int remainingSeconds;

  /// 正在播放的白噪音
  final WhiteNoiseType? whiteNoiseType;

  /// 白噪音是否开启
  final bool whiteNoiseOn;

  /// 上次作废原因（用于宠物提示文案）
  final String lastAbandonReason;

  /// 切出 App 的时间戳（用于计算切出时长）
  final DateTime? pendingExitAt;

  /// 已进行的秒数
  int get elapsedSeconds => planMinutes * 60 - remainingSeconds;

  /// 进度 0.0 - 1.0
  double get progress {
    final total = planMinutes * 60;
    if (total <= 0) return 0;
    return (elapsedSeconds / total).clamp(0.0, 1.0);
  }

  /// 剩余时间格式化 mm:ss
  String get remainingLabel {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get isActive =>
      status == PomodoroStatus.running || status == PomodoroStatus.paused;

  PomodoroState copyWith({
    PomodoroStatus? status,
    String? taskId,
    String? taskTitle,
    int? planMinutes,
    int? remainingSeconds,
    WhiteNoiseType? whiteNoiseType,
    bool? whiteNoiseOn,
    String? lastAbandonReason,
    DateTime? pendingExitAt,
    bool clearPendingExit = false,
    bool clearWhiteNoise = false,
  }) {
    return PomodoroState(
      status: status ?? this.status,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      planMinutes: planMinutes ?? this.planMinutes,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      whiteNoiseType:
          clearWhiteNoise ? null : (whiteNoiseType ?? this.whiteNoiseType),
      whiteNoiseOn: whiteNoiseOn ?? this.whiteNoiseOn,
      lastAbandonReason: lastAbandonReason ?? this.lastAbandonReason,
      pendingExitAt:
          clearPendingExit ? null : (pendingExitAt ?? this.pendingExitAt),
    );
  }
}

/// 番茄钟状态管理器
///
/// **防作弊核心逻辑（对应需求模块 2）：**
/// 1. 时钟只在 running 状态下走；
/// 2. 切出 App（paused）→ 记录切出时间戳，暂停计时与白噪音；
/// 3. 切回 App（resumed）→ 计算切出时长：
///    - 超过宽限时间（默认 5 分钟）→ **本次计时作废，不发任何奖励**；
///    - 未超过 → 恢复计时。
/// 4. 结束 → 写入本地数据库（加经验、发宠物币），返回结果供 UI 播放动画。
class PomodoroController extends Notifier<PomodoroState>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _startTime;
  final List<VoidCallback> _abandonListeners = [];

  DatabaseService get _db => ref.read(databaseProvider);

  /// 宽限时间（分钟），从设置读取
  int get _allowAbandonMinutes =>
      _db.getSettings().allowAbandonMinutes;

  @override
  PomodoroState build() {
    // 注册应用生命周期监听
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    return const PomodoroState();
  }

  /// 注册作废回调（UI 层用来播放宠物垂头丧气动画）
  void addAbandonListener(VoidCallback listener) {
    _abandonListeners.add(listener);
  }

  void removeAbandonListener(VoidCallback listener) {
    _abandonListeners.remove(listener);
  }

  // ==================== 生命周期防作弊 ====================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // 切出 App：记录时间戳 + 暂停计时与白噪音
        _onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // 切回 App：判断是否超时
        _onAppResumed();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// 切出 App 时的处理
  void _onAppPaused() {
    if (state.status != PomodoroStatus.running) return;
    _timer?.cancel();
    _timer = null;

    state = state.copyWith(
      status: PomodoroStatus.paused,
      pendingExitAt: DateTime.now(),
      // 白噪音同时暂停
      whiteNoiseOn: false,
    );
  }

  /// 切回 App 时的处理 —— 这里是防作弊的关键判定点
  void _onAppResumed() {
    final exitAt = state.pendingExitAt;
    if (exitAt == null) return;

    final awaySeconds = DateTime.now().difference(exitAt).inSeconds;
    final allowedSeconds = _allowAbandonMinutes * 60;

    if (awaySeconds > allowedSeconds) {
      // ---------- 超过宽限时间：本次作废，不发放任何奖励 ----------
      _abort(
        '切出 App 超过 $_allowAbandonMinutes 分钟',
        silent: false,
      );
    } else {
      // ---------- 未超时：恢复计时 ----------
      state = state.copyWith(
        status: PomodoroStatus.running,
        clearPendingExit: true,
      );
      _startTimer();
    }
  }

  // ==================== 计时控制 ====================

  /// 开始番茄钟
  ///
  /// [task] 为选中的任务，[minutes] 为计划时长，[whiteNoise] 为初始白噪音。
  void start({
    required Task task,
    required int minutes,
    WhiteNoiseType? whiteNoise,
  }) {
    _timer?.cancel();
    _startTime = DateTime.now();

    state = PomodoroState(
      status: PomodoroStatus.running,
      taskId: task.id,
      taskTitle: task.title,
      planMinutes: minutes,
      remainingSeconds: minutes * 60,
      whiteNoiseType: whiteNoise,
      whiteNoiseOn: whiteNoise != null,
    );

    _startTimer();

    // 同步任务状态为「进行中」（对应截图：任务卡实时走秒）
    _db.saveTask(task.copyWith(
      status: TaskStatus.doing,
      startedAt: DateTime.now(),
    ));
    ref.read(dataRevisionProvider.notifier).bump();
  }

  /// 启动 1 秒间隔的计时器
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status != PomodoroStatus.running) return;

      final next = state.remainingSeconds - 1;
      if (next <= 0) {
        state = state.copyWith(remainingSeconds: 0);
        _finish();
      } else {
        state = state.copyWith(remainingSeconds: next);
      }
    });
  }

  /// 手动暂停（用户主动点击暂停按钮）
  void pause() {
    if (state.status != PomodoroStatus.running) return;
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(
      status: PomodoroStatus.paused,
      whiteNoiseOn: false,
    );
  }

  /// 手动恢复
  void resume() {
    if (state.status != PomodoroStatus.paused) return;
    state = state.copyWith(
      status: PomodoroStatus.running,
      clearPendingExit: true,
    );
    _startTimer();
  }

  /// 用户主动放弃
  void giveUp() {
    if (!state.isActive) return;
    _abort('主动放弃', silent: true);
  }

  /// 切换白噪音
  void toggleWhiteNoise(WhiteNoiseType type) {
    if (!state.isActive) return;
    final same = state.whiteNoiseType == type;
    state = state.copyWith(
      whiteNoiseType: same ? null : type,
      whiteNoiseOn: !same,
      clearWhiteNoise: same,
    );
  }

  /// 播放 / 暂停白噪音
  void setWhiteNoisePlaying(bool playing) {
    state = state.copyWith(whiteNoiseOn: playing && state.whiteNoiseType != null);
  }

  // ==================== 完成与作废 ====================

  /// 正常完成 —— 发放奖励 + 写入数据库
  Future<PomodoroOutcome> _finish() async {
    _timer?.cancel();
    _timer = null;

    final taskId = state.taskId;
    final childId = _db.getActiveChild()?.id;
    final actualMinutes = state.planMinutes;

    if (childId == null) {
      state = state.copyWith(status: PomodoroStatus.finished, whiteNoiseOn: false);
      return const PomodoroOutcome(success: false);
    }

    // ---------- 发放奖励 ----------
    // 奖励细则：宠物币 + 宠物经验，与任务自身的奖励类型无关（番茄钟统一发宠物币）
    final rewardCoin = 10 + actualMinutes ~/ 5 * 2; // 基础 10 + 每 5 分钟加 2
    final expGain = 15 + actualMinutes;             // 基础 15 + 每分钟 1 点经验

    var leveledUp = false;
    final pet = _db.getActivePet(childId);
    if (pet != null) {
      await _db.addPetExp(pet.id, expGain);
      final after = _db.pets.get(pet.id) as Pet?;
      leveledUp = after != null && after.level > pet.level;
    }
    await _db.changeCoin(childId, RewardType.petCoin, rewardCoin);

    // ---------- 完成任务 ----------
    if (taskId != null) {
      final task = _db.tasks.get(taskId) as Task?;
      if (task != null) {
        await _db.saveTask(task.copyWith(
          status: TaskStatus.done,
          completedAt: DateTime.now(),
          lastCompletedAt: DateTime.now(),
          completedPomodoros: task.completedPomodoros + 1,
          clearStartedAt: true,
        ));
      }
    }

    // ---------- 写入番茄钟会话记录（供数据报告统计学习时长） ----------
    final now = DateTime.now();
    await _db.savePomodoroSession(PomodoroSession(
      id: _db.newId('pomo_'),
      childId: childId,
      taskId: taskId,
      planMinutes: state.planMinutes,
      actualMinutes: actualMinutes,
      startTime: _startTime ?? now.subtract(Duration(minutes: actualMinutes)),
      endTime: now,
      isCompleted: true,
      whiteNoiseType: state.whiteNoiseType,
      rewardType: RewardType.petCoin,
      rewardValue: rewardCoin,
      expGained: expGain,
    ));

    state = state.copyWith(
      status: PomodoroStatus.finished,
      whiteNoiseOn: false,
      clearPendingExit: true,
    );
    // 番茄钟完成会推进「专注次数 / 学习时长 / 宠物等级」类勋章进度
    // 注：上方 314 行已对 childId 做过 null 守卫并提前 return，此处必非空。
    await _db.refreshAchievements(childId);
    ref.read(dataRevisionProvider.notifier).bump();

    return PomodoroOutcome(
      success: true,
      rewardCoin: rewardCoin,
      expGained: expGain,
      leveledUp: leveledUp,
      dialogue: _db.pickDialogue(
        trigger: PetDialogueTrigger.pomodoroDone,
        name: _db.getActiveChild()?.name ?? '',
      ),
    );
  }

  /// 作废 —— 不发放任何奖励（对应需求：无惩罚，仅宠物动画提示）
  void _abort(String reason, {required bool silent}) {
    _timer?.cancel();
    _timer = null;

    final childId = _db.getActiveChild()?.id;
    final now = DateTime.now();

    // 记录作废会话，便于数据审计（但不计入学习时长）
    if (childId != null) {
      _db.savePomodoroSession(PomodoroSession(
        id: _db.newId('pomo_'),
        childId: childId,
        taskId: state.taskId,
        planMinutes: state.planMinutes,
        actualMinutes: state.elapsedSeconds ~/ 60,
        startTime: _startTime ?? now,
        endTime: now,
        isCompleted: false,
        isAbandoned: true,
        abandonReason: reason,
        whiteNoiseType: state.whiteNoiseType,
      ));
    }

    // 任务回到未完成状态（不惩罚，允许重新开始）
    final taskId = state.taskId;
    if (taskId != null) {
      final task = _db.tasks.get(taskId) as Task?;
      if (task != null) {
        _db.saveTask(task.copyWith(
          status: TaskStatus.todo,
          clearStartedAt: true,
        ));
      }
    }

    state = state.copyWith(
      status: PomodoroStatus.aborted,
      whiteNoiseOn: false,
      lastAbandonReason: reason,
      clearPendingExit: true,
    );
    ref.read(dataRevisionProvider.notifier).bump();

    if (!silent) {
      for (final l in _abandonListeners) {
        l();
      }
    }
  }

  /// 重置回初始状态
  void reset() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
    state = const PomodoroState();
  }

  /// 获取作废时的宠物台词（对应需求：宠物垂头丧气说本次任务失败）
  String abortDialogue() =>
      _db.pickDialogue(trigger: PetDialogueTrigger.pomodoroFailed);
}

/// 番茄钟结果
class PomodoroOutcome {
  const PomodoroOutcome({
    required this.success,
    this.rewardCoin = 0,
    this.expGained = 0,
    this.leveledUp = false,
    this.dialogue = '',
  });

  final bool success;
  final int rewardCoin;
  final int expGained;
  final bool leveledUp;
  final String dialogue;
}

final pomodoroProvider =
    NotifierProvider<PomodoroController, PomodoroState>(PomodoroController.new);
