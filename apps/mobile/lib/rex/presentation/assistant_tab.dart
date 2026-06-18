import 'package:flutter/material.dart';

enum AssistantTab { chat, memory, goals, chats }

extension AssistantTabContract on AssistantTab {
  String get id {
    return switch (this) {
      AssistantTab.chat => 'chat',
      AssistantTab.memory => 'memory',
      AssistantTab.goals => 'goals',
      AssistantTab.chats => 'chats',
    };
  }

  String get label {
    return switch (this) {
      AssistantTab.chat => 'Chat',
      AssistantTab.memory => 'Knows',
      AssistantTab.goals => 'Goals',
      AssistantTab.chats => 'Chats',
    };
  }

  IconData get icon {
    return switch (this) {
      AssistantTab.chat => Icons.chat_bubble_outline_rounded,
      AssistantTab.memory => Icons.psychology_alt_outlined,
      AssistantTab.goals => Icons.flag_outlined,
      AssistantTab.chats => Icons.forum_outlined,
    };
  }

  String get semanticLabel => 'Assistant $label tab';

  Key get key => ValueKey<String>('assistant-tab-$id');
}
