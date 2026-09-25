/// 3D 宠物渲染组件 —— 平台分发入口
///
/// - Web：HtmlElementView 嵌入 <model-viewer>（pet_3d_viewer_web.dart）
/// - Android/iOS：webview_flutter 加载本地 asset 的 viewer.html（pet_3d_viewer_io.dart）
/// - 其他平台：占位图形（本文件）
///
/// 所有实现共享同一接口 [Pet3DViewer]，业务层（PetAvatar 等）不感知平台差异。
export 'pet_3d_viewer_stub.dart'
    if (dart.library.html) 'pet_3d_viewer_web.dart'
    if (dart.library.io) 'pet_3d_viewer_io.dart';
