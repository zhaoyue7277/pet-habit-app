import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Android/iOS 端 3D 宠物渲染：WebView 加载本地 asset 的 viewer.html
///
/// viewer.html 与 model-viewer.min.js、pet_*.glb 同位于 assets/3d/，
/// 通过 loadFlutterAsset 以 file:///android_asset/flutter_assets/ 形式加载，
/// 相对路径自动解析到同目录 —— 全程离线，无需 INTERNET 权限。
class Pet3DViewer extends StatefulWidget {
  const Pet3DViewer({
    super.key,
    required this.modelPath,
    this.width,
    this.height,
  });

  /// 模型文件名（assets/3d/ 目录下），如 pet_1.glb
  final String modelPath;
  final double? width;
  final double? height;

  @override
  State<Pet3DViewer> createState() => _Pet3DViewerState();
}

class _Pet3DViewerState extends State<Pet3DViewer> {
  late final WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            // 页面加载完成后由 Flutter 指定模型（相对路径，同目录解析）
            _controller.runJavaScript(
              'setPetModel("./${widget.modelPath}")',
            );
            if (mounted) setState(() => _loaded = true);
          },
        ),
      )
      ..loadFlutterAsset('assets/3d/viewer.html');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          // 模型解码（Draco + 大纹理）需要时间，解码完成前显示占位
          if (!_loaded)
            const Center(
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
        ],
      ),
    );
  }
}
