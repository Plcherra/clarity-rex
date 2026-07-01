@JS()
library;

import 'dart:js_interop';

/// Minimal Plaid Link JS bindings for Flutter web.
///
/// Requires `link-initialize.js` in `apps/mobile/web/index.html`.
extension type PlaidHandler._(JSObject _) implements JSObject {
  external void open();
  external void destroy();
}

extension type Plaid._(JSObject _) implements JSObject {
  external static PlaidHandler create(WebConfiguration options);
}

@JS()
@anonymous
@staticInterop
class WebConfiguration {
  external factory WebConfiguration({
    String? token,
    String? receivedRedirectUri,
    required JSFunction onSuccess,
    required JSFunction onLoad,
    required JSFunction onExit,
    required JSFunction onEvent,
  });
}

@JS('window.location.href')
external String get windowLocationHref;

@JS('window.history.replaceState')
external void historyReplaceState(
  JSAny? state,
  String title,
  String url,
);

Map<dynamic, dynamic> jsObjectToMap(Object? jsObject) {
  if (jsObject is Map) return jsObject;
  if (jsObject is! JSAny) return {};
  final dartified = jsObject.dartify();
  if (dartified is Map) return dartified;
  return {};
}

String jsString(Object? value) {
  if (value == null) return '';
  return value.toString();
}

String? jsNullableString(Object? value) {
  if (value == null) return null;
  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

List<dynamic> jsList(Object? value) {
  if (value is List) return value;
  return const [];
}
