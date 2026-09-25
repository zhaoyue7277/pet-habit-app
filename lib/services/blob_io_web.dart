// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Web：把 blob URL（或任意同源/跨源可访问 URL）读成字节。
///
/// 用 `XMLHttpRequest` + `responseType = 'arraybuffer'`，
/// 比 `fetch` 兼容性更广（部分旧 WebView 无 fetch）。
Future<Uint8List> httpGetBytes(String url) async {
  final completer = Completer<Uint8List>();
  final xhr = html.HttpRequest();
  xhr.open('GET', url);
  xhr.responseType = 'arraybuffer';
  xhr.onLoad.listen((_) {
    final buf = xhr.response;
    if (buf is ByteBuffer) {
      completer.complete(Uint8List.view(buf));
    } else if (buf is Uint8List) {
      completer.complete(buf);
    } else {
      completer.complete(Uint8List(0));
    }
  });
  xhr.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('读取音频数据失败'));
    }
  });
  xhr.send();
  return completer.future;
}

/// Web：释放 createObjectURL 产生的 blob，避免内存泄漏
Future<void> revokeObjectUrl(String url) async {
  try {
    html.Url.revokeObjectUrl(url);
  } catch (_) {
    // 忽略：部分环境下 URL 已被自动回收
  }
}
