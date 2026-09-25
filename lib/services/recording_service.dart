import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
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
