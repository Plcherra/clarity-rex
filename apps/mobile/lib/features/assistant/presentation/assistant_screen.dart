import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accountability/presentation/pages/accountability_page.dart';
import '../chat/application/chat_controller.dart';
import '../chat/presentation/pages/chat_page.dart';
import '../chat/presentation/pages/conversation_list_page.dart';
import '../memory/presentation/pages/memory_page.dart';
import '../voice/application/voice_call_controller.dart';
import 'assistant_tab.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _lastTabIndex = AssistantTab.chat.index;
  var _isStartingVoiceFromTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AssistantTab.values.length,
      vsync: this,
      initialIndex: AssistantTab.chat.index,
    )..addListener(_handleTabControllerChange);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabControllerChange)
      ..dispose();
    super.dispose();
  }

  void _handleTabControllerChange() {
    if (_tabController.indexIsChanging ||
        _tabController.index == _lastTabIndex) {
      return;
    }
    _lastTabIndex = _tabController.index;
    _handleAssistantTabSelected(AssistantTab.values[_tabController.index]);
  }

  void _handleAssistantTabSelected(AssistantTab tab) {
    if (tab == AssistantTab.voice) {
      unawaited(_startVoiceFromVoiceTab());
    }
  }

  void _openChatTab() {
    _tabController.animateTo(AssistantTab.chat.index);
  }

  Future<void> _startVoiceFromVoiceTab() async {
    if (_isStartingVoiceFromTab || ref.read(voiceCallProvider).isCallActive) {
      return;
    }

    _isStartingVoiceFromTab = true;
    final bool started;
    try {
      started = await ref
          .read(voiceCallProvider.notifier)
          .startCall(conversationId: ref.read(chatProvider).conversationId);
    } finally {
      _isStartingVoiceFromTab = false;
    }

    if (!mounted || started) {
      return;
    }

    final errorMessage =
        ref.read(voiceCallProvider).errorMessage ?? 'Could not start Rex.';
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(errorMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Assistant',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            _AssistantTabNavigation(
              controller: _tabController,
              onTabSelected: _handleAssistantTabSelected,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final tab in AssistantTab.values)
                    _AssistantTabContent(
                      tab: tab,
                      onConversationSelected: _openChatTab,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantTabNavigation extends StatelessWidget {
  const _AssistantTabNavigation({
    required this.controller,
    required this.onTabSelected,
  });

  final TabController controller;
  final ValueChanged<AssistantTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: TabBar(
        controller: controller,
        onTap: (index) => onTabSelected(AssistantTab.values[index]),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(
          horizontal: 3,
          vertical: 3,
        ),
        indicator: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
        ),
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        labelPadding: EdgeInsets.zero,
        tabs: [
          for (final tab in AssistantTab.values)
            Tab(
              key: tab.key,
              height: 74,
              iconMargin: const EdgeInsets.only(bottom: 4),
              icon: Semantics(
                label: tab.semanticLabel,
                button: true,
                child: Icon(tab.icon, size: 27),
              ),
              text: tab.label,
            ),
        ],
      ),
    );
  }
}

class _AssistantTabContent extends StatelessWidget {
  const _AssistantTabContent({
    required this.tab,
    required this.onConversationSelected,
  });

  final AssistantTab tab;
  final VoidCallback onConversationSelected;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      AssistantTab.chat => const ChatPage(showAppBar: false),
      AssistantTab.voice => const ChatPage(showAppBar: false),
      AssistantTab.memory => const MemoryPage(showAppBar: false),
      AssistantTab.goals => const AccountabilityPage(showAppBar: false),
      AssistantTab.chats => ConversationListPage(
        showAppBar: false,
        onConversationSelected: onConversationSelected,
      ),
    };
  }
}
