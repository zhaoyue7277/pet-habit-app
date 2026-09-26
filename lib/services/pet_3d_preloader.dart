/// 3D 宠物资产预加载服务
///
/// 【为什么需要预加载】
/// 每个 `pet_*.glb` 约 5MB，Draco 解码器约 1MB。若等到用户进入首页、
/// 组件首次 build 才开始从 APK assets 读取并解码，会出现：
///   - 首屏 3D 区域长时间空白 / 转圈；
///   - 反复进出页面时重复解码，卡顿感明显。
///
/// 这里在 App 启动阶段（闪屏期间）把三类资源提前读进 Flutter 的 asset 缓存：
///   1. `viewer.html` —— WebView 要加载的页面骨架；
///   2. `model-viewer.min.js` —— 渲染引擎（936KB）；
///   3. `draco/*` —— Draco 解码器（js + wasm，约 1MB）；
///   4. 当前宠物对应的 `pet_*.glb`。
///
/// 说明：`rootBundle.load()` 会把资源读进内存/平台侧缓存，后续 WebView
/// 通过 AssetLoader 再取时命中已缓存的文件，省掉磁盘 IO 与解压开销。
///
/// 本服务**不阻塞**启动流程：调用方用 `unawaited` 方式触发即可，
/// 失败也不抛异常（3D 加载本身有超时兜底，不因预加载失败而影响主流程）。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 3D 相关静态资源（与 pubspec.yaml 的 assets 声明保持一致）
class _Assets {
  static const String viewer = 'assets/3d/viewer.html';
  static const String engine = 'assets/3d/model-viewer.min.js';
  static const List<String> draco = <String>[
    'assets/3d/draco/draco_decoder.js',
    'assets/3d/draco/draco_decoder.wasm',
    'assets/3d/draco/draco_wasm_wrapper.js',
  ];
  /// 全部宠物模型 —— 共 3 个品种，总量约 16MB。
  /// 只在「预热」时读，一次即可覆盖所有品种切换场景。
  static const List<String> models = <String>[
    'assets/3d/pet_1.glb',
    'assets/3d/pet_2.glb',
    'assets/3d/pet_3.glb',
  ];
}

/// 预加载结果（用于日志与自检，不参与业务判断）
class Pet3DPreloadReport {
  const Pet3DPreloadReport({
    required this.loaded,
    required this.failed,
    required this.elapsedMs,
  });

  final List<String> loaded;
  final Map<String, String> failed;
  final int elapsedMs;

  bool get ok => failed.isEmpty;

  @override
  String toString() =>
      'Pet3DPreload(ok=$ok, loaded=${loaded.length}, '
      'failed=${failed.length}, ${elapsedMs}ms)';
}

/// 3D 宠物资产预加载器（单例，幂等）
class Pet3DPreloader {
  Pet3DPreloader._();

  static final Pet3DPreloader instance = Pet3DPreloader._();

  bool _started = false;
  Future<Pet3DPreloadReport>? _future;

  /// 已完成的报告（预热结束后可读）
  Pet3DPreloadReport? report;

  /// 启动预加载（幂等：重复调用返回同一个 Future）
  ///
  /// [includeModels] 为 true 时连模型一起读；默认预热时不读模型，
  /// 避免启动阶段一次性吃掉 16MB 内存。模型在「宠物中心 / 首页」
  /// 真正需要时再按品种单读。
  Future<Pet3DPreloadReport> warmUp({bool includeModels = false}) {
    if (_started && _future != null) return _future!;
    _started = true;
    _future = _run(includeModels: includeModels);
    return _future!;
  }

  Future<Pet3DPreloadReport> _run({required bool includeModels}) async {
    final sw = Stopwatch()..start();
    final loaded = <String>[];
    final failed = <String, String>{};

    final targets = <String>[
      _Assets.viewer,
      _Assets.engine,
      ..._Assets.draco,
      if (includeModels) ..._Assets.models,
    ];

    // 并行读取：资源之间无依赖，串行会白白拉长预热时间
    await Future.wait(
      targets.map((path) async {
        try {
          final data = await rootBundle.load(path);
          // 触碰一下字节，确认真的读到了内容（防止拿到空 buffer）
          if (data.lengthInBytes > 0) {
            loaded.add(path);
          } else {
            failed[path] = '空文件';
          }
        } catch (e) {
          failed[path] = '$e';
        }
      }),
    );

    sw.stop();
    final r = Pet3DPreloadReport(
      loaded: loaded,
      failed: failed,
      elapsedMs: sw.elapsedMilliseconds,
    );
    report = r;

    if (!r.ok) {
      // 预加载失败不阻断主流程，只记录 —— 3D 组件自身有超时与失败态兜底
      debugPrint('[Pet3DPreloader] 部分资源预加载失败: ${r.failed}');
    } else {
      debugPrint('[Pet3DPreloader] $r');
    }
    return r;
  }

  /// 单独预热某个模型（宠物品种确定后调用，避免一次读全部）
  Future<void> warmModel(String modelPath) async {
    try {
      await rootBundle.load(modelPath);
    } catch (e) {
      debugPrint('[Pet3DPreloader] 预热模型失败 $modelPath: $e');
    }
  }
}

/// 便捷入口：App 启动时调用，不阻塞主流程
void startPet3DPreload({bool includeModels = false}) {
  // 不 await：让预热在后台跑，闪屏/首屏正常推进
  unawaited(Pet3DPreloader.instance.warmUp(includeModels: includeModels));
}
