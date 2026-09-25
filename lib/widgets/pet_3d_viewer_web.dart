// Web 端 3D 宠物渲染：HtmlElementView 嵌入 <model-viewer>
//
// model-viewer 组件库由 index.html 引入（assets/3d/model-viewer.min.js，
// 本地化、不依赖外网）。Draco 解码器内嵌在该 bundle 中，离线可解码。
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class Pet3DViewer extends StatelessWidget {
  const Pet3DViewer({
    super.key,
    required this.modelPath,
    this.width,
    this.height,
  });

  /// 模型资源路径（相对 base href），如 assets/3d/pet_1.glb
  final String modelPath;
  final double? width;
  final double? height;

  /// platformViewRegistry 每个 viewType 只允许注册一次。
  /// 不同模型使用不同 viewType（按文件名区分），避免「第一个注册的
  /// 模型工厂闭包捕获参数，导致所有 3D 宠物渲染成同一个模型」的问题。
  static final Set<String> _registered = <String>{};

  void _registerFactory(String viewType, String modelPath) {
    if (_registered.contains(viewType)) return;
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final el = html.Element.tag('model-viewer');
      el
        ..setAttribute('src', modelPath)
        ..setAttribute('auto-rotate', '')
        ..setAttribute('camera-controls', '')
        ..setAttribute('disable-pan', '')
        ..setAttribute('shadow-intensity', '1')
        ..setAttribute('rotation-per-second', '30deg')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';
      return el;
    });
  }

  @override
  Widget build(BuildContext context) {
    // viewType 与模型绑定：pet-3d-mv-pet_1.glb / pet-3d-mv-pet_2.glb ...
    final fileName = modelPath.split('/').last;
    final viewType = 'pet-3d-mv-$fileName';
    _registerFactory(viewType, modelPath);
    return SizedBox(
      width: width,
      height: height,
      child: HtmlElementView(viewType: viewType),
    );
  }
}
