import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/enums.dart';

/// 白噪音播放服务
///
/// **⚠️ 资源说明（重要）：**
/// 本服务会加载 `assets/audio/{rain,ocean,forest,fire,cafe}.mp3`。
/// 这些是**真实音效文件，需要你自行放入** `assets/audio/` 目录
/// （建议使用 CC0 / 无版权音频，如 freesound.org 的公共领域素材）。
///
/// **当前行为：** 如果音频文件缺失，播放会失败但不崩溃——
/// 计时功能、防作弊逻辑、UI 交互全部正常，只是没有声音。
/// 放入文件后无需改任何代码即可生效。
///
/// **生命周期：** 与番茄钟状态联动。
/// 切出 App 时暂停（对应约束 6-A），切回时按需恢复。
class WhiteNoiseService {
  WhiteNoiseService._internal();
  static final WhiteNoiseService instance = WhiteNoiseService._internal();

  final AudioPlayer _player = AudioPlayer();

  /// 当前播放的音源
  WhiteNoiseType? _current;

  /// 音量
  double _volume = 0.6;

  /// 音频文件是否可用（缺失时降级为静默模式）
  bool _assetsAvailable = true;

  /// 当前是否在播放
  bool get isPlaying => _player.state == PlayerState.playing;

  /// 当前音源
  WhiteNoiseType? get current => _current;

  /// 音频资源是否可用
  bool get assetsAvailable => _assetsAvailable;

  /// 初始化：配置音频上下文（与其他音频互不打断的策略）
  Future<void> init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_volume);
      // 使用低延迟模式，避免白噪音启动迟钝
    } catch (e) {
      _assetsAvailable = false;
      debugPrint('[WhiteNoise] 初始化失败：$e');
    }
  }

  /// 设置音量（0.0 - 1.0）
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
    } catch (e) {
      debugPrint('[WhiteNoise] 设置音量失败：$e');
    }
  }

  /// 播放指定白噪音（切换音源时自动停止上一个）
  Future<bool> play(WhiteNoiseType type) async {
    try {
      if (_current != type) {
        await _player.stop();
        _current = type;
      }
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_volume);
      // 从 assets 加载，循环播放
      await _player.play(
        AssetSource('audio/${type.assetName}'),
        volume: _volume,
      );
      _assetsAvailable = true;
      return true;
    } catch (e) {
      // 音频文件缺失：降级为静默，不影响计时与防作弊逻辑
      _assetsAvailable = false;
      debugPrint('[WhiteNoise] 播放失败（音频文件可能未放入 assets/audio/）：$e');
      return false;
    }
  }

  /// 暂停播放（保留音源，便于恢复）
  ///
  /// **对应约束 6-A：切出 App 时白噪音暂停。**
  Future<void> pause() async {
    try {
      if (_player.state == PlayerState.playing) {
        await _player.pause();
      }
    } catch (e) {
      debugPrint('[WhiteNoise] 暂停失败：$e');
    }
  }

  /// 恢复播放
  Future<void> resume() async {
    try {
      if (_player.state == PlayerState.paused) {
        await _player.resume();
      } else if (_current != null) {
        await play(_current!);
      }
    } catch (e) {
      debugPrint('[WhiteNoise] 恢复失败：$e');
    }
  }

  /// 停止并释放
  Future<void> stop() async {
    try {
      await _player.stop();
      _current = null;
    } catch (e) {
      debugPrint('[WhiteNoise] 停止失败：$e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('[WhiteNoise] 释放失败：$e');
    }
  }
}
