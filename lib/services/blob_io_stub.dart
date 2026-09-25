import 'dart:typed_data';

/// Web：把 blob URL 内容读成字节
///
/// 实现位于 `blob_io_web.dart`（`dart.library.js_interop` 条件导入）。
/// native 平台不会走到这里 —— `RecordingService` 只在 `kIsWeb` 时调用。
Future<Uint8List> httpGetBytes(String url) async {
  throw UnsupportedError('httpGetBytes 仅在 Web 平台可用');
}

/// Web：释放 createObjectURL 产生的 blob，避免内存泄漏
Future<void> revokeObjectUrl(String url) async {
  // native 无需处理
}
