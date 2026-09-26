// Web 端 3D 宠物渲染：HtmlElementView 嵌入 <model-viewer>
//
// model-viewer 组件库与 Draco 解码器均由 index.html 引入（本地化、不依赖外网）：
//   - assets/3d/model-viewer.min.js      —— 渲染引擎（Draco 解码器**不**内嵌其中）
//   - assets/3d/draco/*                  —— 自托管 Draco 解码器（js + wasm）
// index.html 里通过 `ModelViewerElement.dracoDecoderLocation` 指向本地目录。
//
// 【v1.2.4 修复】之前只引入 model-viewer.min.js 而未自托管 Draco，
// 导致 model-viewer 去 gstatic.com 下载解码器（国内不可达）→ 模型永远
// 解码失败 → 界面空白。现已改为全程离线。
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class Pet3DViewer extends StatefulWidget {
  const Pet3DViewer({
    super.key,
    required this.modelPath,
    this.width,
    this.height,
    this.onTap,
  });

  /// 模型资源路径（相对 base href），如 assets/3d/pet_1.glb
  final String modelPath;
  final double? width;
  final double? height;

  /// 点击模型回调（按位移 + 时长双阈值区分点击与拖拽旋转）
  final VoidCallback? onTap;

  @override
  State<Pet3DViewer> createState() => _Pet3DViewerState();
}

class _Pet3DViewerState extends State<Pet3DViewer> {
  /// platformViewRegistry 每个 viewType 只允许注册一次。
  /// 不同模型使用不同 viewType（按文件名区分），避免「第一个注册的
  /// 模型工厂闭包捕获参数，导致所有 3D 宠物渲染成同一个模型」的问题。
  static final Set<String> _registered = <String>{};

  bool _ready = false;
  bool _failed = false;
  String _errDetail = '';

  String get _fileName => widget.modelPath.split('/').last;
  String get _viewType => 'pet-3d-mv-$_fileName';

  /// Web 端不需要 Dart 侧注入：model-viewer 直接以 src 加载。
  /// 资源放在 Flutter Web 的 assets/ 下，真实 URL 是 assets/assets/3d/xxx。
  void _registerFactory(String viewType, String modelPath) {
    if (_registered.contains(viewType)) return;
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final el = html.Element.tag('model-viewer');
      el
        ..setAttribute('src', 'assets/$modelPath')
        ..setAttribute('auto-rotate', '')
        ..setAttribute('camera-controls', '')
        ..setAttribute('disable-pan', '')
        // v1.3.0：纯水平旋转 —— phi 锁死 90deg（水平正视），theta 完全放开。
        // 与 assets/3d/viewer.html 保持完全一致，避免两端行为分叉。
        ..setAttribute('camera-orbit', '0deg 90deg auto')
        ..setAttribute('min-camera-orbit', '-Infinity 90deg auto')
        ..setAttribute('max-camera-orbit', 'Infinity 90deg auto')
        ..setAttribute('interaction-prompt', 'none')
        ..setAttribute('shadow-intensity', '1')
        ..setAttribute('rotation-per-second', '18deg')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';

      // 与 Android 侧一致：监听真实解码状态，便于 UI 展示 loading / 失败态
      el.addEventListener('load', (event) {
        if (!mounted) return;
        setState(() {
          _ready = true;
          _failed = false;
        });
      });
      el.addEventListener('error', (event) {
        if (!mounted) return;
        setState(() {
          _failed = true;
          _errDetail = '模型加载失败';
        });
      });

      // v1.3.0：点击交互。
      // Flutter Web 的 HtmlElementView 是真实 DOM，事件直接绑在元素上即可
      // （不需要像 Android 那样监听 document 捕获阶段 —— 那里是为了
      //  绕开 InAppWebView 里 model-viewer 的 Shadow DOM 吞事件问题）。
      // 同样用「位移 + 时长」双阈值区分点击与拖拽旋转。
      const tapMoveTolerance = 10; // px
      const tapTimeLimit = 300; // ms
      var downX = 0.0;
      var downY = 0.0;
      var downAt = 0;
      var tracking = false;

      el.addEventListener('pointerdown', (event) {
        // 【踩坑记录 v1.3.0】dart:html 的 MouseEvent **没有**公开的
        // clientX / clientY getter —— 它只暴露：
        //   · 私有 `_clientX` / `_clientY`（@JSName 映射，外部不可用）
        //   · 公开的 `Point get client`（即 client.x / client.y）
        // PointerEvent 虽然 extends MouseEvent，但同样没有公开 clientX。
        // 所以正确写法是取 `.client` 这个 Point。
        final me = event as html.MouseEvent;
        final p = me.client;
        tracking = true;
        downX = p.x.toDouble();
        downY = p.y.toDouble();
        downAt = DateTime.now().millisecondsSinceEpoch;
      });
      el.addEventListener('pointerup', (event) {
        if (!tracking) return;
        tracking = false;
        final me = event as html.MouseEvent;
        final p = me.client;
        final dx = (p.x - downX).abs();
        final dy = (p.y - downY).abs();
        final dt = DateTime.now().millisecondsSinceEpoch - downAt;
        if (dx > tapMoveTolerance || dy > tapMoveTolerance) return;
        if (dt > tapTimeLimit) return;
        if (!mounted) return;
        widget.onTap?.call();
      });
      el.addEventListener('pointercancel', (event) {
        tracking = false;
      });

      return el;
    });
  }

  @override
  Widget build(BuildContext context) {
    _registerFactory(_viewType, widget.modelPath);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: _viewType),
          if (!_ready || _failed)
            Center(
              child: _failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.view_in_ar_outlined,
                          size: 40,
                          color: Color(0xFF9AA6B2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errDetail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9AA6B2),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
            ),
        ],
      ),
    );
  }
}
