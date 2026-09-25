// ============================================================================
// Flutter Web 启动配置（自定义）
// ----------------------------------------------------------------------------
// 目的：强制从同目录 ./canvaskit/ 加载渲染引擎，而不是默认的
//      https://www.gstatic.com/flutter-canvaskit/<engineRevision>/
//      国内网络访问 gstatic 困难，会导致长时间白屏。
//
// 写法参照 Flutter SDK 官方示例：
//   flutter/examples/hello_world/web/flutter_bootstrap.js
// ============================================================================

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // 使用本地 CanvasKit 包，避免访问 gstatic CDN
    canvasKitBaseUrl: "/canvaskit/",
  },
});
