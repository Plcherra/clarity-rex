import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the Assistant Chat sub-tab is visible (shell on Assistant + Chat tab).
final assistantChatVisibleProvider =
    NotifierProvider<AssistantChatVisibleNotifier, bool>(
      AssistantChatVisibleNotifier.new,
    );

class AssistantChatVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setVisible(bool visible) {
    if (state == visible) {
      return;
    }
    state = visible;
  }
}

/// Increment to request navigation to Assistant > Chat from anywhere in the shell.
final assistantChatTabRequestProvider =
    NotifierProvider<AssistantChatTabRequestNotifier, int>(
      AssistantChatTabRequestNotifier.new,
    );

class AssistantChatTabRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}
