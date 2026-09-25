import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Android/iOS 端 3D 宠物渲染：InAppWebView 加载本地 asset 的 viewer.html
///
/// viewer.html 与 model-viewer.min.js、pet_*.glb 同位于 assets/3d/。
///
/// 【为什么不用 file:// + allowFileAccessFromFileURLs】
/// Android WebView 从 API 30 起废弃了 allowFileAccessFromFileURLs /
/// allowUniversalAccessFromFileURLs，且 file:// 页面 fetch 同目录 file://
/// 资源会触发 CORS 拦截，导致 model-viewer 无法加载 glb。
///
/// 【改用 WebViewAssetLoader（官方推荐）】
/// 通过 https://appassets.androidplatform.net/assets/<相对路径> 以 http(s)
/// 协议访问 APK 内 assets，天然满足同源策略，fetch 不会被拦截。
/// Flutter 的 flutter_assets 位于 assets/flutter_assets/ 下，
/// 因此路径写为 assets/flutter_assets/assets/3d/viewer.html。
/// 全程本机内存映射，无需联网、无需 INTERNET 权限。
class Pet3DViewer extends StatefulWidget {
  const Pet3DViewer({
    super.key,
    required this.modelPath,
    this.width,
    this.height,
  });

  /// 模型资源路径（相对 asset 根），如 assets/3d/pet_1.glb
  final String modelPath;
  final double? width;
  final double? height;

  @override
  State<Pet3DViewer> createState() => _Pet3DViewerState();
}

class _Pet3DViewerState extends State<Pet3DViewer> {
  bool _loaded = false;

  /// AssetLoader 域名下的资源根路径（指向 APK 内 flutter_assets）
  static const String _assetBase =
      'https://appassets.androidplatform.net/assets/flutter_assets/';

  @override
  Widget build(BuildContext context) {
    // viewer.html 与 pet_*.glb 同位于 assets/3d/，取文件名做同目录相对路径
    final fileName = widget.modelPath.split('/').last;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('${_assetBase}assets/3d/viewer.html'),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              // 通过 AssetLoader 以 https 协议访问，无需放开 file:// 权限
              allowFileAccess: false,
              allowFileAccessFromFileURLs: false,
              allowUniversalAccessFromFileURLs: false,
              // 允许加载 https://appassets.androidplatform.net 的资源
              webViewAssetLoader: WebViewAssetLoader(
                pathHandlers: [
                  AssetsPathHandler(path: '/assets/'),
                ],
              ),
            ),
            onLoadStop: (controller, url) {
              controller.evaluateJavascript(
                source: 'setPetModel("./$fileName")',
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
