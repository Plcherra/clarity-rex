import 'package:web/web.dart' as web;

/// Browser-reported online flag. False means clearly offline.
Future<bool> isDeviceLikelyOnline() async {
  return web.window.navigator.onLine;
}
