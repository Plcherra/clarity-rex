import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/home_screen_widget_snapshot.dart';

/// iOS App Group + WidgetKit reload. No-op on other platforms.
final class HomeScreenWidgetBridge {
  HomeScreenWidgetBridge({MethodChannel? channel})
    : _channel = channel ??
          const MethodChannel(HomeScreenWidgetSnapshot.channelName);

  static final HomeScreenWidgetBridge instance = HomeScreenWidgetBridge();

  final MethodChannel _channel;
  void Function()? onOpenOverview;
  var _listening = false;

  bool get _isIos {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  void listenForOpens(void Function() onOverview) {
    onOpenOverview = onOverview;
    if (!_isIos || _listening) {
      return;
    }
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'opened') {
        onOpenOverview?.call();
      }
    });
    _consumePendingOpen();
  }

  void stopListening() {
    onOpenOverview = null;
    if (!_listening) {
      return;
    }
    _listening = false;
    _channel.setMethodCallHandler(null);
  }

  Future<void> publish(HomeScreenWidgetSnapshot snapshot) {
    if (!_isIos) {
      return Future<void>.value();
    }
    return _channel.invokeMethod<void>(
      'publish',
      snapshot.toAppGroupFields(),
    );
  }

  Future<void> clear() {
    if (!_isIos) {
      return Future<void>.value();
    }
    return _channel.invokeMethod<void>('clear');
  }

  Future<void> _consumePendingOpen() async {
    final host = await _channel.invokeMethod<String>('consumePending');
    if (host == HomeScreenWidgetSnapshot.openHost) {
      onOpenOverview?.call();
    }
  }
}
