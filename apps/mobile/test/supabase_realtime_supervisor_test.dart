import 'dart:async';

import 'package:clarity/core/supabase/supabase_realtime_supervisor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refreshes the session before the first subscribe', () async {
    var refreshes = 0;
    final controller = StreamController<Object?>.broadcast();
    addTearDown(controller.close);
    final supervisor = SupabaseRealtimeSupervisor(
      refreshSession: () async {
        refreshes += 1;
      },
      hasSession: () => true,
    );

    await supervisor.start([
      SupabaseRealtimeWatch(
        name: 'accounts',
        open: () => controller.stream,
        onData: (_) {},
      ),
    ]);

    expect(refreshes, 1);
    expect(supervisor.isListening, isTrue);
    supervisor.stop();
    expect(supervisor.isListening, isFalse);
  });

  test('onError cancels the dead subscription and resubscribes', () async {
    var refreshes = 0;
    var opens = 0;
    final controllers = <StreamController<Object?>>[];
    final supervisor = SupabaseRealtimeSupervisor(
      refreshSession: () async {
        refreshes += 1;
      },
      hasSession: () => true,
      restartBackoff: Duration.zero,
    );

    await supervisor.start([
      SupabaseRealtimeWatch(
        name: 'accounts',
        open: () {
          opens += 1;
          final controller = StreamController<Object?>();
          controllers.add(controller);
          return controller.stream;
        },
        onData: (_) {},
      ),
    ]);
    expect(opens, 1);
    expect(controllers.single.hasListener, isTrue);

    controllers.single.addError(
      Exception('InvalidJWTToken: Token has expired 12 seconds ago'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(opens, 2);
    expect(refreshes, greaterThanOrEqualTo(2));
    expect(controllers.first.hasListener, isFalse);
    expect(controllers.last.hasListener, isTrue);

    supervisor.stop();
    for (final controller in controllers) {
      await controller.close();
    }
  });

  test('resume refreshes JWT and starts a new subscribe', () async {
    var refreshes = 0;
    var opens = 0;
    final supervisor = SupabaseRealtimeSupervisor(
      refreshSession: () async {
        refreshes += 1;
      },
      hasSession: () => true,
    );
    final controllers = <StreamController<Object?>>[];

    await supervisor.start([
      SupabaseRealtimeWatch(
        name: 'transactions',
        open: () {
          opens += 1;
          final controller = StreamController<Object?>.broadcast();
          controllers.add(controller);
          return controller.stream;
        },
        onData: (_) {},
      ),
    ]);
    await supervisor.recoverAfterResume();

    expect(opens, 2);
    expect(refreshes, 2);
    expect(controllers.first.hasListener, isFalse);

    supervisor.stop();
    for (final controller in controllers) {
      await controller.close();
    }
  });

  test('does not subscribe when there is no session', () async {
    var opens = 0;
    final supervisor = SupabaseRealtimeSupervisor(
      refreshSession: () async {},
      hasSession: () => false,
    );

    await supervisor.start([
      SupabaseRealtimeWatch(
        name: 'budgets',
        open: () {
          opens += 1;
          return const Stream.empty();
        },
        onData: (_) {},
      ),
    ]);

    expect(opens, 0);
    supervisor.stop();
  });
}
