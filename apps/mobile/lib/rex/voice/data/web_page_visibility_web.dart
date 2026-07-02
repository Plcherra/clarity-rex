import 'dart:js_interop';

import 'package:web/web.dart' as web;

typedef WebPageVisibilityCallback = void Function(bool isVisible);

web.EventListener? _listener;

void listenWebPageVisibility(WebPageVisibilityCallback callback) {
  disposeWebPageVisibilityListener();
  void handler(web.Event _) {
    callback(!web.document.hidden);
  }

  _listener = handler.toJS;
  web.document.addEventListener('visibilitychange', _listener!);
  // Avoid running voice lifecycle callbacks during Riverpod provider build.
  Future<void>.microtask(() => callback(!web.document.hidden));
}

void disposeWebPageVisibilityListener() {
  final listener = _listener;
  if (listener == null) {
    return;
  }
  web.document.removeEventListener('visibilitychange', listener);
  _listener = null;
}
