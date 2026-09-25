/// 平台工具：Web 侧 blob URL 读字节 + 释放
///
/// 条件导入分发：
///   - `dart.library.js_interop`（Web）→ `blob_io_web.dart`
///   - 其他 → `blob_io_stub.dart`（native 不会调用，仅保证可编译）
export 'blob_io_stub.dart' if (dart.library.js_interop) 'blob_io_web.dart';
