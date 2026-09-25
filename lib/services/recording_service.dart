import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// 录音服务（朗读打卡）
///
/// **为什么用 `record` 插件？**
/// - Android 走系统 MediaRecorder / MediaCodec，无需额外原生代码；
/// - Web 走 `getUserMedia` + `MediaRecorder`，同一套 Dart API；
/// - 录音结果直接拿到字节流存入 Hive，**不落地文件**，
///   既规避 FileProvider / 存储权限问题，也天然满足「数据不出本机」的承诺。
///
/// **为什么用 `startStream` 而不是 `start`？**
/// `start` 需要提供文件路径，`stop()` 只返回路径字符串：
/// Android 返回文件路径、Web 返回 blob URL，两端读取方式完全不同，
/// 需要额外的平台分支与临时文件清理。
/// `startStream` 直接在内存中累积 `Uint8List`，**两端行为完全一致**，
/// 且停止后无需清理任何临时文件。代价是数据先留在内存——
/// 但录音上限 3 分钟 / 64kbps ≈ 1.4MB，完全可接受。
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

  /// Web 上 AAC 编码不可用，需回退到 opus（webm 容器）
  static const RecordConfig _nativeConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
    autoGain: true,
    echoCancel: true,
    noiseSuppress: true,
  );

  static const RecordConfig _webConfig = RecordConfig(
    encoder: AudioEncoder.opus,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
  );

  bool _recording = false;
  DateTime? _startedAt;
  Timer? _limitTimer;

  /// 流式录音累积的字节块
  final List<Uint8List> _chunks = <Uint8List>[];
  StreamSubscription<Uint8List>? _streamSub;

  bool get isRecording => _recording;

  /// 当前录音已持续时长
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// 当前累积的音频字节数（用于粗粒度展示）
  int get bufferedBytes =>
      _chunks.fold(0, (sum, chunk) => sum + chunk.length);

  /// 是否具备录音条件（权限 + 硬件）
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('[Recording] 权限检查失败：$e');
      return false;
    }
  }

  /// 当前平台推荐的音频 MIME（用于回放时告知播放器）
  String get recommendedMimeType => kIsWeb ? 'audio/webm' : 'audio/mp4';

  /// 开始录音
  ///
  /// [maxDurationMs] 到达后回调 [onAutoStop]，由调用方随即执行 [stop] 保存数据。
  /// 返回 `null` 表示成功，否则返回失败原因（用于 UI 提示）。
  Future<String?> start({
    int maxDurationMs = 180000,
    void Function()? onAutoStop,
  }) async {
    if (_recording) return null;

    try {
      if (!await _recorder.hasPermission()) {
        return '没有麦克风权限，请在系统设置里允许「小宠习惯」录音';
      }

      final config = kIsWeb ? _webConfig : _nativeConfig;

      // Web 上若 opus 不被支持，再退到默认（浏览器自动协商容器）
      if (kIsWeb) {
        final supported = await _recorder.isEncoderSupported(config.encoder);
        if (!supported) {
          debugPrint('[Recording] 当前浏览器不支持 opus，回退到默认编码');
        }
      }

      _chunks.clear();
      final stream = await _recorder.startStream(config);
      _streamSub = stream.listen(
        (chunk) {
          // 到达上限后丢弃后续数据，避免内存无界增长
          if (_recording) _chunks.add(chunk);
        },
        onError: (Object e) => debugPrint('[Recording] 录音流异常：$e'),
        cancelOnError: false,
      );

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
      // ⚠️ 顺序很关键：必须先 cancel 流、再置 _recording = false。
      // 因为流监听回调里有 `if (_recording)` 守卫，
      // 若先置 false，stop() 期间到达的**尾部数据**会被丢弃，
      // 导致录音末尾被切掉（表现为「最后一句没录上」）。
      await _streamSub?.cancel();
      _streamSub = null;
      // 释放底层录音器资源（stream 模式下返回值可忽略）
      await _recorder.stop();

      _recording = false;
      _startedAt = null;

      final bytes = _joinChunks();
      if (bytes.isEmpty) return null;

      return RecordedAudio(
        bytes: bytes,
        durationMs: durationMs,
        mimeType: recommendedMimeType,
      );
    } catch (e) {
      debugPrint('[Recording] 停止录音失败：$e');
      _recording = false;
      _startedAt = null;
      return null;
    } finally {
      _chunks.clear();
    }
  }

  Uint8List _joinChunks() {
    final total = bufferedBytes;
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
    _recording = false;
    _startedAt = null;
    try {
      await _streamSub?.cancel();
      _streamSub = null;
      await _recorder.cancel();
    } catch (e) {
      debugPrint('[Recording] 取消录音失败：$e');
    } finally {
      _chunks.clear();
    }
  }

  /// 实时音量（dBFS），用于让波形跟随真实音量起伏
  ///
  /// 平台不支持时返回 0，UI 侧按「静默」处理。
  Future<double> currentAmplitude() async {
    try {
      final amp = await _recorder.getAmplitude();
      // current 为 dBFS 负值（0 = 满幅，-60 ≈ 静音），映射到 0..1
      final normalized = (amp.current + 60) / 60;
      return normalized.clamp(0.0, 1.0);
    } catch (_) {
      return 0;
    }
  }

  // ==================== 回放 ====================

  /// 播放一段录音字节
  ///
  /// `BytesSource` 在 Android 写入临时缓存后播放，在 Web 包装为 blob URL，
  /// 两端均由 audioplayers 自动适配。
  Future<bool> playBytes(Uint8List bytes, {String mimeType = 'audio/mp4'}) async {
    try {
      await _player.stop();
      await _player.play(BytesSource(bytes, mimeType: mimeType));
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
  Stream<PlayerState> get onPlaybackStateChanged => _player.onPlayerStateChanged;

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

/// 录音结果
class RecordedAudio {
  const RecordedAudio({
    required this.bytes,
    required this.durationMs,
    this.mimeType = 'audio/mp4',
  });

  final Uint8List bytes;
  final int durationMs;
  final String mimeType;
}
