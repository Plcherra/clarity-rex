import 'dart:async';

import 'package:flutter/foundation.dart';

import 'supabase_exceptions.dart';
import 'supabase_realtime_errors.dart';

typedef SupabaseRealtimeRefresh = Future<void> Function();

final class SupabaseRealtimeWatch {
  const SupabaseRealtimeWatch({
    required this.name,
    required this.open,
    required this.onData,
  });

  final String name;
  final Stream<Object?> Function() open;
  final void Function(Object? data) onData;
}

/// One refresh + retry path for finance `.stream()` watchers.
///
/// Refreshes the Supabase JWT before subscribe, cancels a dead subscription
/// on error, and resubscribes. Accounts, transactions, budgets, and
/// categories share this — do not copy-paste five listeners.
final class SupabaseRealtimeSupervisor {
  SupabaseRealtimeSupervisor({
    required this.refreshSession,
    required this.hasSession,
    this.maxRestartAttempts = 3,
    this.restartBackoff = const Duration(milliseconds: 400),
  });

  final SupabaseRealtimeRefresh refreshSession;
  final bool Function() hasSession;
  final int maxRestartAttempts;
  final Duration restartBackoff;

  final List<SupabaseRealtimeWatch> _watches = [];
  final List<StreamSubscription<Object?>> _subscriptions = [];
  var _generation = 0;
  var _restartAttempts = 0;
  var _restartQueued = false;
  var _started = false;

  bool get isListening => _subscriptions.isNotEmpty;

  Future<void> start(List<SupabaseRealtimeWatch> watches) async {
    if (_started && _subscriptions.isNotEmpty) return;
    _watches
      ..clear()
      ..addAll(watches);
    _started = true;
    _restartAttempts = 0;
    await _subscribeAll();
  }

  Future<void> recoverAfterResume() async {
    if (!hasSession()) return;
    _restartAttempts = 0;
    await _subscribeAll();
  }

  Future<void> restart() async {
    _restartAttempts = 0;
    await _subscribeAll();
  }

  void stop() {
    _generation++;
    _started = false;
    _restartQueued = false;
    _restartAttempts = 0;
    _cancelSubscriptions();
    _watches.clear();
  }

  Future<void> _subscribeAll() async {
    final generation = ++_generation;
    _cancelSubscriptions();
    if (!hasSession()) return;
    await refreshSession();
    if (generation != _generation) return;
    for (final watch in _watches) {
      if (generation != _generation) return;
      _subscribe(watch);
    }
  }

  void _subscribe(SupabaseRealtimeWatch watch) {
    try {
      _subscriptions.add(
        watch.open().listen(
          watch.onData,
          onError: (Object error, StackTrace stack) {
            _handleStreamError(watch.name, error, stack);
          },
          cancelOnError: false,
        ),
      );
    } on SupabaseAuthRequiredException {
      return;
    } on Object catch (error, stack) {
      _handleStreamError(watch.name, error, stack);
    }
  }

  void _handleStreamError(String name, Object error, StackTrace stack) {
    debugPrint('[Clarity][Realtime] $name failed: $error');
    if (isRecoverableSupabaseRealtimeError(error)) {
      debugPrint('[Clarity][Realtime] recovering $name');
    } else {
      debugPrintStack(stackTrace: stack);
    }
    unawaited(_restartAfterError());
  }

  Future<void> _restartAfterError() async {
    if (_restartQueued || !_started) return;
    if (_restartAttempts >= maxRestartAttempts) return;
    _restartQueued = true;
    _restartAttempts += 1;
    final delay = restartBackoff * _restartAttempts;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    _restartQueued = false;
    if (!_started || !hasSession()) return;
    await _subscribeAll();
  }

  void _cancelSubscriptions() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}
