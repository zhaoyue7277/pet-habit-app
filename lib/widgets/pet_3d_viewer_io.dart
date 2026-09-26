import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/pet_3d_preloader.dart';

/// Android/iOS 端 3D 宠物渲染：InAppWebView 加载本地 asset 的 viewer.html
///
/// viewer.html 与 model-viewer.min.js、pet_*.glb 同位于 assets/3d/。
///
/// 【为什么不用 file:// + allowFileAccessFromFileURLs】
/// Android WebView 从 API 30 起废弃了 allowFileAccessFromFileURLs /
/// allowUniversalAccessFromFileURLs，且 file:// 页面 fetch 同目录 file://
/// 资源会触发 CORS 拦截，导致 model-viewer 无法加载 glb。
///
/// 【主方案：WebViewAssetLoader（官方推荐）】
/// https://appassets.androidplatform.net/assets/flutter_assets/assets/3d/viewer.html
/// 以 https 协议访问 APK 内 assets，天然同源，fetch 不被拦截，全程离线。
///
/// 【v1.2.3 修复：为什么之前一直转圈】
/// 旧实现只监听 onLoadStop 就置 `_loaded = true`，但：
///   1. 若 AssetLoader 未生效，页面根本加载不出来 → onLoadStop 不触发 →
///      转圈永不结束（用户真机现象）；
///   2. 即使页面加载成功，model-viewer 的 glb 解码仍需数秒，
///      提前去掉转圈会看到空白。
/// 现在改为：
///   - JS 侧通过 callHandler 上报「模型真正 load 事件」后才结束转圈；
///   - 增加超时兜底（默认 20s），超时展示失败态与重试按钮，不再无限转圈；
///   - 监听 onReceivedError，加载失败立即给出可操作提示。
class Pet3DViewer extends StatefulWidget {
  const Pet3DViewer({
    super.key,
    required this.modelPath,
    this.width,
    this.height,
    this.onTap,
  });

  /// 模型资源路径（相对 asset 根），如 assets/3d/pet_1.glb
  final String modelPath;
  final double? width;
  final double? height;

  /// 点击模型回调
  ///
  /// viewer.html 内部按「位移 + 时长」双阈值区分「点击」与「拖拽旋转」，
  /// 只有真正的点击才会触发本回调（拖拽转模型不会）。
  final VoidCallback? onTap;

  @override
  State<Pet3DViewer> createState() => _Pet3DViewerState();
}

enum _LoadState { loading, ready, failed }

class _Pet3DViewerState extends State<Pet3DViewer>
    with SingleTickerProviderStateMixin {
  _LoadState _state = _LoadState.loading;
  String? _errDetail;
  Timer? _timeoutTimer;
  int _retrySeed = 0;
  InAppWebViewController? _controller;

  /// 点击弹跳动画控制器
  ///
  /// 【为什么用外层 Transform 而不是让模型自己动】
  /// 当前 pet_*.glb 是**纯静态网格**（animations: 0 / skins: 0 / 无 morph targets），
  /// 无法播放骨骼或形态键动画。所以改为在 WebView **外层**做整体变换 ——
  /// 不依赖模型资产，观感上也足够表达「被点到了」。
  late final AnimationController _bounceController;

  /// AssetLoader 域名下的资源根路径（指向 APK 内 flutter_assets）
  static const String _assetBase =
      'https://appassets.androidplatform.net/assets/flutter_assets/';

  /// 模型解码超时（ms）—— Draco + 5MB 纹理在低端机上较慢，给足余量
  static const int _loadTimeoutMs = 20000;

  String get _fileName => widget.modelPath.split('/').last;
  String get _viewerUrl => '${_assetBase}assets/3d/viewer.html';

  @override
  void initState() {
    super.initState();
    // 预热当前品种的 glb（约 5MB）：让 WebView 真正 fetch 时命中 asset 缓存，
    // 显著缩短首帧出现时间。失败静默，不影响加载流程。
    Pet3DPreloader.instance.warmModel(widget.modelPath);
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _startTimeout();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  /// 播放一次点击弹跳
  void _playBounce() {
    _bounceController.forward(from: 0);
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(milliseconds: _loadTimeoutMs), () {
      if (!mounted) return;
      if (_state == _LoadState.loading) {
        setState(() {
          _state = _LoadState.failed;
          _errDetail = '模型加载超时';
        });
      }
    });
  }

  void _retry() {
    setState(() {
      _state = _LoadState.loading;
      _errDetail = null;
      _retrySeed++;
    });
    _startTimeout();
    // 重新导航到 viewer 页面
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(_viewerUrl)));
  }

  /// 页面加载完成后注入模型路径
  Future<void> _injectModel(InAppWebViewController controller) async {
    // setPetModel 定义在 viewer.html 中；若因时序问题尚未就绪，重试若干次
    for (int i = 0; i < 10; i++) {
      final ok = await controller.evaluateJavascript(source: '''
        (function () {
          if (typeof window.setPetModel === 'function') {
            window.setPetModel("./$_fileName");
            return true;
          }
          return false;
        })();
      ''');
      if (ok == true) return;
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// 把 JS 上报的原始错误码翻译成家长/用户看得懂的提示。
  ///
  /// 保留原始码在括号里 —— 便于真机截图排查，又不至于让人一头雾水。
  String _friendlyError(String detail) {
    if (detail.isEmpty) return '模型加载失败';
    final d = detail.toLowerCase();
    if (d.contains('draco-missing')) {
      return '3D 组件缺少解码器\n(请更新到最新版本)';
    }
    if (d.contains('loadfailure')) {
      return '模型文件损坏或格式不支持';
    }
    if (d.contains('timeout-watchdog')) {
      return '模型加载超时';
    }
    return '模型加载失败\n($detail)';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ---------- 弹跳变换（外层，作用于整个 WebView）----------
          //
          // 【为什么用 translate + scale 而不是 rotate】
          // WebView 的 rotate/3D 变换在部分低端机上容易触发昂贵的图层重绘，
          // 而 translate/scale 是 GPU 合成友好操作，掉帧风险低得多。
          // 位移幅度（18px）与缩放缓动（1.0 → 1.06 → 1.0）刻意做得克制，
          // 既能明确感知「被点到了」，又不会显得浮夸。
          AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) {
              final t = _bounceController.value;
              // sin 曲线：0 → 1 → 0，形成一次完整的「起跳-落回」
              final lift = math.sin(t * math.pi);
              return Transform.translate(
                offset: Offset(0, -lift * 18),
                child: Transform.scale(
                  scale: 1.0 + lift * 0.06,
                  child: child,
                ),
              );
            },
            child: _buildWebView(),
          ),

          // ---------- 加载中 ----------
          if (_state == _LoadState.loading)
            const Center(
              child: SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),

          // ---------- 加载失败：给可操作的重试 ----------
          if (_state == _LoadState.failed)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.view_in_ar_outlined,
                    size: 40,
                    color: Color(0xFF9AA6B2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errDetail ?? '模型加载失败',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9AA6B2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _retry,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('点击重试', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// WebView 主体（抽出来是为了让弹跳动画能包在它外层）
  Widget _buildWebView() {
    // 出错后隐藏 WebView，避免残留白底
    if (_state == _LoadState.failed) return const SizedBox.shrink();

    return InAppWebView(
      key: ValueKey('pet3d-$_retrySeed'),
      initialUrlRequest: URLRequest(url: WebUri(_viewerUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        // 通过 AssetLoader 以 https 协议访问，无需放开 file:// 权限
        allowFileAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        webViewAssetLoader: WebViewAssetLoader(
          pathHandlers: [
            AssetsPathHandler(path: '/assets/'),
          ],
        ),
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        // JS → Flutter：模型真实加载状态
        controller.addJavaScriptHandler(
          handlerName: 'petModelState',
          callback: (data) {
            // flutter_inappwebview 6.x：callback 入参即 JS 传参列表本身
            // （非 { args: [...] } 包装对象），取 data[0] 为状态字符串。
            final state = (data.isNotEmpty) ? '${data.first}' : '';
            // data[1] 是 JS 侧附带的原因说明（如 loadfailure / draco-missing）
            final detail = (data.length > 1) ? '${data[1]}' : '';
            if (!mounted) return null;
            if (state == 'loaded') {
              _timeoutTimer?.cancel();
              setState(() => _state = _LoadState.ready);
            } else if (state == 'error') {
              _timeoutTimer?.cancel();
              setState(() {
                _state = _LoadState.failed;
                _errDetail = _friendlyError(detail);
              });
            } else if (state == 'tapped') {
              // v1.3.0：模型被点击（viewer.html 已区分点击与拖拽旋转）
              // ① 立即播放弹跳，给即时的反馈
              // ② 上抛给页面层，由页面触发台词气泡
              _playBounce();
              widget.onTap?.call();
            }
            return null;
          },
        );
      },
      onLoadStop: (controller, url) async {
        await _injectModel(controller);
      },
      onReceivedError: (controller, request, error) {
        // 仅主框架错误才算致命
        if (!mounted) return;
        if (request.isForMainFrame == true) {
          _timeoutTimer?.cancel();
          setState(() {
            _state = _LoadState.failed;
            _errDetail = error.description;
          });
        }
      },
    );
  }
}
