import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:record/record.dart';

import 'blob_io.dart';

/// 录音服务（朗读打卡）
///
/// **为什么用 `record` 插件？**
/// - Android 走系统 MediaRecorder / MediaCodec，无需额外原生代码；
/// - Web 走 `getUserMedia` + `MediaRecorder`，同一套 Dart API；
/// - 录音结果直接拿到字节流存入 Hive，**不落地业务文件**，
///   既规避 FileProvider / 存储权限问题，也天然满足「数据不出本机」的承诺。
///
/// **⚠️ 关键平台差异（v1.2.3 修复）**
///
/// `record` 7.x 的 `startStream()` 在两端支持度**完全不同**：
///
/// | 平台 | `startStream` 支持 | 说明 |
/// |---|---|---|
/// | Android | ✅ 任意编码器 | `startRecordingToStream` 内部复用 `startRecording`，
/// |         |               | aacLc / opus 均可，数据从 EventChannel 流式返回 |
/// | iOS     | ✅ 任意编码器 | 同上 |
/// | **Web** | ❌ **仅 `pcm16bits`** | `MediaRecorderDelegate.startStream`
/// |         |                    | 直接 `throw UnimplementedError()`；
/// |         |                    | `Recorder.startStream` 对非 pcm16bits
/// |         |                    | 抛 `Exception('Stream not supported.')` |
///
/// 因此**不能**两端统一走 `startStream` —— 在 Web 上会立刻抛异常。
/// 本服务按平台分两条路径：
///
/// - **native**：`startStream(config)` → 内存累积 `Uint8List`，无需临时文件；
/// - **web**：`start(config, path: '')` → 录制结束后拿到 blob URL →
///   `HTTP GET` 读回字节 → `URL.revokeObjectURL` 释放。
///
/// 两条路径对外都产出同一份 `RecordedAudio`，UI 层无感知。
///
/// **权限：** Android 侧需在 `AndroidManifest.xml` 声明 `RECORD_AUDIO`，
/// 首次调用 [start] 时由系统弹窗实时征询；Web 侧由浏览器弹窗征询。
///
/// **降级策略：** 权限被拒 / 设备无麦克风 / Web 非 https 环境时，
/// [start] 返回失败原因字符串，UI 提示用户，其余功能不受影响。
class RecordingService {
  RecordingService._internal();
  static final RecordingService instance = RecordingService._internal();

  final AudioRecorder _recorder = AudioRecorder();

  /// 回放用播放器（与白噪音播放器相互独立，避免互抢音频焦点）
  final AudioPlayer _player = AudioPlayer();

  /// Android/iOS：MediaRecorder 系，AAC-LC 兼容性最好（系统播放器/微信都能放）
  static const RecordConfig _nativeConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
    autoGain: true,
    echoCancel: true,
    noiseSuppress: true,
  );

  /// Web：MediaRecorder 在浏览器里最可靠的组合是 `audio/webm; codecs=opus`；
  /// AAC（`audio/mp4;codecs=mp4a`）在多数 Chrome/Firefox 上
  /// `MediaRecorder.isTypeSupported` 返回 false。
  static const RecordConfig _webConfig = RecordConfig(
    encoder: AudioEncoder.opus,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
  );

  bool _recording = false;
  DateTime? _startedAt;
  Timer? _limitTimer;

  /// native 流式录音累积的字节块
  final List<Uint8List> _chunks = <Uint8List>[];
  StreamSubscription<Uint8List>? _streamSub;

  // ==================== v1.4.0 防作弊状态 ====================
  //
  // 【为什么录音也要防作弊？】
  //
  // 旧逻辑只校验「时长 ≥ 3 秒」就发奖励 —— 孩子只要点开始、静音坐 3 秒、
  // 点停止，就能刷到心愿币。番茄钟早就用 `didChangeAppLifecycleState`
  // 防了「切出去干别的」，录音打卡却完全没有，属于明显的短板。
  //
  // 这里把番茄钟的那套判定搬过来，并额外加一条「静音检测」：
  //   1. 录音期间切出 App 超过宽限时长 → 本次作废；
  //   2. 全程几乎没有声音 → 判定「没真的读」，本次作废；
  //   3. 有效发声时长不足 → 本次作废。
  //
  // 三条一起构成「人真的对着麦克风读了」的最小充分条件。
  // 注意：我们**不做语音识别、不上传**，只统计音量大小这一层
  // 物理指标，不涉及任何隐私内容采集。

  /// 上一次离开 App 的时间（切出时记录，切回时判定）
  DateTime? _awaySince;

  /// 累计「有效发声」毫秒（音量高于阈值才计入）
  int _voicedMs = 0;

  /// 本次录音的音量采样总次数
  int _sampleCount = 0;

  /// 本次录音中采到「有声音」的次数
  int _voicedSamples = 0;

  /// 最近一次采样的音量（0~1），供 UI 展示
  double _lastAmplitude = 0;

  /// 作废原因（null 表示未作废）
  String? _voidReason;

  /// 判断「这一段算不算有声音」的音量阈值。
  ///
  /// 0.16 的来历：`currentAmplitude()` 把 dBFS 映射到 0~1，安静室内
  /// 底噪一般落在 0.05~0.12，正常说话在 0.3~0.8。取 0.16 能滤掉底噪，
  /// 又不会把「小声读」误杀。
  static const double _voiceThreshold = 0.16;

  /// 本次录音是否已被判定作废
  bool get isVoided => _voidReason != null;

  /// 作废原因（UI 提示用）
  String? get voidReason => _voidReason;

  /// 有效发声时长（毫秒）
  int get voicedMs => _voicedMs;

  /// 发声占比（0~1）
  double get voicedRatio =>
      _sampleCount == 0 ? 0 : _voicedSamples / _sampleCount;

  /// 最近一次采样音量（0~1）
  double get lastAmplitude => _lastAmplitude;

  Duration get elapsed {
    final started = _startedAt;
    if (started == null) return Duration.zero;
    return DateTime.now().difference(started);
  }

  /// 当前平台录出的数据 MIME 类型
  String get _mimeType => kIsWeb ? 'audio/webm' : 'audio/mp4';

  /// 开始录音
  ///
  /// 返回 `null` 表示成功，否则返回失败原因（用于 UI 提示）。
  Future<String?> start({
    int maxDurationMs = 180000,
    void Function()? onAutoStop,
  }) async {
    if (_recording) return null;

    // ---------- 重置本轮防作弊状态 ----------
    _resetGuardState();

    try {
      if (!await _recorder.hasPermission()) {
        return '没有麦克风权限，请在系统设置里允许「小宠习惯」录音';
      }

      _chunks.clear();

      if (kIsWeb) {
        // Web：只能用文件模式（start + stop 拿 blob URL）。
        // startStream 在 Web 上除 pcm16bits 外一律抛异常。
        final supported = await _recorder.isEncoderSupported(
          _webConfig.encoder,
        );
        if (!supported) {
          return '当前浏览器不支持录音编码，请换用 Chrome / Edge 最新版';
        }
        await _recorder.start(_webConfig, path: '');
      } else {
        // native：流式录音，任意编码器均可用，数据直接进内存
        final stream = await _recorder.startStream(_nativeConfig);
        _streamSub = stream.listen(
          (chunk) {
            // 到达上限后丢弃后续数据，避免内存无界增长
            if (_recording) _chunks.add(chunk);
          },
          onError: (Object e) => debugPrint('[Recording] 录音流异常：$e'),
          cancelOnError: false,
        );
      }

      _startedAt = DateTime.now();
      _recording = true;

      // 时长上限兜底：到点自动停止，避免无限录制撑爆内存 / Hive
      _limitTimer?.cancel();
      _limitTimer = Timer(Duration(milliseconds: maxDurationMs), () {
        if (_recording) onAutoStop?.call();
      });

      return null;
    } catch (e) {
      debugPrint('[Recording] 启动录音失败：$e');
      await _streamSub?.cancel();
      _streamSub = null;
      _recording = false;
      _startedAt = null;
      return '录音启动失败，请检查设备麦克风是否可用';
    }
  }

  /// 停止录音并返回音频字节
  ///
  /// 返回 `null` 表示没有有效数据（如未开始、被系统抢占、数据为空）。
  Future<RecordedAudio?> stop() async {
    _limitTimer?.cancel();
    _limitTimer = null;

    if (!_recording && _startedAt == null) return null;

    final durationMs = elapsed.inMilliseconds;

    try {
      if (kIsWeb) {
        // Web：stop() 返回 blob URL，需要 HTTP 读回字节再释放
        final blobUrl = await _recorder.stop();
        _recording = false;
        _startedAt = null;

        if (blobUrl == null || blobUrl.isEmpty) return null;

        final bytes = await _readBlobUrl(blobUrl);
        if (bytes.isEmpty) return null;

        return RecordedAudio(
          bytes: bytes,
          durationMs: durationMs,
          mimeType: _mimeType,
        );
      }

      // native：先 cancel 流、再 stop()、最后置 _recording = false。
      // ⚠️ 顺序很关键：流回调里有 `if (_recording)` 守卫，
      // 若先置 false，stop() 期间到达的**尾部数据**会被丢弃，
      // 导致录音末尾被切掉（表现为「最后一句没录上」）。
      await _streamSub?.cancel();
      _streamSub = null;
      await _recorder.stop();

      _recording = false;
      _startedAt = null;

      final bytes = _joinChunks();
      if (bytes.isEmpty) return null;

      return RecordedAudio(
        bytes: bytes,
        durationMs: durationMs,
        mimeType: _mimeType,
      );
    } catch (e) {
      debugPrint('[Recording] 停止录音失败：$e');
      _recording = false;
      _startedAt = null;
      return null;
    } finally {
      _chunks.clear();
      // 注意：这里**不清**防作弊统计 —— stop() 之后 UI 还要调
      // validate() 做判定，统计必须保留到下一轮 start() 才重置。
    }
  }

  /// Web：把 blob URL 读成字节，并立即 revoke 释放内存
  Future<Uint8List> _readBlobUrl(String blobUrl) async {
    try {
      return await httpGetBytes(blobUrl);
    } finally {
      // 无论成功与否都释放 blob，避免内存泄漏
      await revokeObjectUrl(blobUrl);
    }
  }

  Uint8List _joinChunks() {
    final total = _chunks.fold(0, (sum, c) => sum + c.length);
    if (total == 0) return Uint8List(0);
    final out = Uint8List(total);
    var offset = 0;
    for (final chunk in _chunks) {
      out.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return out;
  }

  /// 取消录音并丢弃数据
  Future<void> cancel() async {
    _limitTimer?.cancel();
    _limitTimer = null;
    final wasRecording = _recording;
    _recording = false;
    _startedAt = null;
    try {
      if (kIsWeb && wasRecording) {
        // Web：cancel() 内部 stop + revokeObjectURL，直接丢弃
        await _recorder.cancel();
      } else {
        await _streamSub?.cancel();
        _streamSub = null;
        await _recorder.cancel();
      }
    } catch (e) {
      debugPrint('[Recording] 取消录音失败：$e');
    } finally {
      _chunks.clear();
      // 取消 = 彻底作废，连同防作弊状态一起清空
      _resetGuardState();
    }
  }

  /// 实时音量（0~1），用于让波形跟随真实音量起伏
  ///
  /// **v1.4.0 起，这个函数同时承担「防作弊采样」职责**：
  /// 每次调用都会把音量喂给内部统计（有效发声次数 / 总采样数），
  /// 因此 UI 侧只要照旧每 300ms 调一次即可，防作弊自动生效，
  /// 不需要 UI 额外写任何代码。
  ///
  /// 平台不支持时返回 0，UI 侧按「静默」处理。
  Future<double> currentAmplitude() async {
    double normalized = 0;
    try {
      final amp = await _recorder.getAmplitude();
      // current 为 dBFS 负值（0 = 满幅，-60 ≈ 静音），映射到 0..1
      normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
    } catch (_) {
      normalized = 0;
    }
    _feedGuard(normalized);
    return normalized;
  }

  /// 把一次音量采样喂给防作弊统计
  void _feedGuard(double level) {
    if (!_recording) return;
    _lastAmplitude = level;
    _sampleCount++;
    if (level >= _voiceThreshold) {
      _voicedSamples++;
      // 采样间隔按 300ms 计（UI 固定每 300ms 采一次）
      _voicedMs += 300;
    }
  }

  /// 重置防作弊状态（每次开始录音前调用）
  void _resetGuardState() {
    _awaySince = null;
    _voicedMs = 0;
    _sampleCount = 0;
    _voicedSamples = 0;
    _lastAmplitude = 0;
    _voidReason = null;
  }

  // ==================== 生命周期防作弊（v1.4.0） ====================

  /// 由 UI 层在 `didChangeAppLifecycleState` 中转调。
  ///
  /// **为什么不让 Service 自己 addObserver？**
  /// Service 是全局单例，若自己注册 observer 会活到 App 结束，
  /// 容易与其他模块（番茄钟）抢事件或泄漏。改由录音页在
  /// 进入/退出时转调，生命周期与「一次录音」严格对齐，更干净。
  ///
  /// [allowAwaySeconds] 为宽限秒数：离开不超过这个时长视为
  /// 「误触 / 看一眼时间」，不算作弊。
  void onAppLifecycleChanged(
    AppLifecycleState state, {
    int allowAwaySeconds = 60,
  }) {
    if (!_recording) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // 切出：记下时间点（只记第一次，避免 inactive→paused 连击覆盖）
        _awaySince ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final since = _awaySince;
        _awaySince = null;
        if (since == null) return;
        final away = DateTime.now().difference(since).inSeconds;
        if (away > allowAwaySeconds) {
          _voidReason =
              '录音中途离开了 App（$away 秒），这次不算哦，重新读一次吧～';
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// 停止录音前的最终校验（v1.4.0 核心判定）
  ///
  /// 返回 `null` 表示通过；否则返回**给孩子看的原因**。
  ///
  /// 判定顺序（由重到轻）：
  /// 1. 已经因「切出超时」被标记作废 → 直接拒；
  /// 2. 时长不够 [minValidMs]；
  /// 3. 有效发声时长不够 [minVoicedMs]（静音刷时长的主要拦截点）；
  /// 4. 发声占比过低（一直断断续续 / 大部分时间没声音）。
  String? validate({
    required int minValidMs,
    int minVoicedMs = 1200,
    double minVoicedRatio = 0.12,
  }) {
    if (_voidReason != null) return _voidReason;
    final durationMs = elapsed.inMilliseconds;
    if (durationMs < minValidMs) {
      return '读得太短啦，至少要读满 ${(minValidMs / 1000).ceil()} 秒才算哦';
    }
    // 采样数太少（如设备不支持音量 API）时，退化为「只看时长」，
    // 不能让「拿不到音量」的设备永远无法打卡。
    if (_sampleCount >= 3) {
      if (_voicedMs < minVoicedMs) {
        return '好像一直没出声呢，请对着麦克风大声读出来～';
      }
      if (voicedRatio < minVoicedRatio) {
        return '声音断断续续的，坚持一口气读完会更棒哦～';
      }
    }
    return null;
  }

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  // ==================== 回放 ====================

  /// 播放一段录音字节
  ///
  /// `BytesSource` 在 Android 写入临时缓存后播放，在 Web 包装为 blob URL，
  /// 两端均由 audioplayers 自动适配。
  Future<bool> playBytes(
    Uint8List bytes, {
    String? mimeType,
  }) async {
    try {
      await _player.stop();
      await _player.play(
        BytesSource(bytes, mimeType: mimeType ?? _mimeType),
      );
      return true;
    } catch (e) {
      debugPrint('[Recording] 回放失败：$e');
      return false;
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[Recording] 停止回放失败：$e');
    }
  }

  Stream<void> get onPlaybackComplete => _player.onPlayerComplete;
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  Future<void> dispose() async {
    _limitTimer?.cancel();
    try {
      await _streamSub?.cancel();
      await _recorder.dispose();
      await _player.dispose();
    } catch (e) {
      debugPrint('[Recording] 释放失败：$e');
    }
  }
}

/// 一段录制完成的音频
class RecordedAudio {
  RecordedAudio({
    required this.bytes,
    required this.durationMs,
    required this.mimeType,
  });

  final Uint8List bytes;
  final int durationMs;
  final String mimeType;

  int get byteLength => bytes.length;
}
