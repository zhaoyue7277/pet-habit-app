import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Android/iOS 端 3D 宠物渲染：InAppWebView 加载本地 asset 的 viewer.html
///
/// viewer.html 与 model-viewer.min.js、pet_*.glb 同位于 assets/3d/。
/// model-viewer 通过 fetch 加载 glb（file:// 同目录），因此必须显式开启：
/// - allowFileAccess                 允许 WebView 访问文件
/// - allowFileAccessFromFileURLs     file:// 页面可加载同域 file:// 脚本/资源
/// - allowUniversalAccessFromFileURLs  file:// 页面的 fetch/XHR 可访问 file://
/// 全程离线，无需 INTERNET 权限（保持纯本地单机定位）。
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
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          InAppWebView(
            initialFile: 'assets/3d/viewer.html',
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowFileAccess: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              transparentBackground: true,
            ),
            onLoadStop: (controller, url) {
              // 页面加载完成后指定模型（相对路径，同目录解析）
              controller.evaluateJavascript(
                source: 'setPetModel("./${widget.modelPath}")',
              );
              if (mounted) setState(() => _loaded = true);
            },
          ),
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
