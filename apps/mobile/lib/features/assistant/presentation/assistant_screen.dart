import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accountability/presentation/pages/accountability_page.dart';
import '../chat/presentation/pages/chat_page.dart';
import '../chat/presentation/pages/conversation_list_page.dart';
import '../memory/presentation/pages/memory_page.dart';
import '../voice/presentation/pages/voice_chat_page.dart';
import 'assistant_tab.dart';

const _assistantCompactWidth = 360.0;
const _assistantTabHeight = 74.0;

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AssistantTab.values.length,
      vsync: this,
      initialIndex: AssistantTab.chat.index,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openChatTab() {
    _tabController.animateTo(AssistantTab.chat.index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCompactWidth =
        MediaQuery.sizeOf(context).width < _assistantCompactWidth;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCompactWidth ? 20 : 24,
                10,
                isCompactWidth ? 20 : 24,
                0,
              ),
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
              isCompactWidth: isCompactWidth,
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
    required this.isCompactWidth,
  });

  final TabController controller;
  final bool isCompactWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCompactWidth ? 8 : 12,
        4,
        isCompactWidth ? 8 : 12,
        10,
      ),
      child: TabBar(
        controller: controller,
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
              height: _assistantTabHeight,
              child: _AssistantTabItem(tab: tab),
            ),
        ],
      ),
    );
  }
}

class _AssistantTabItem extends StatelessWidget {
  const _AssistantTabItem({required this.tab});

  final AssistantTab tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: tab.semanticLabel,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 27),
            const SizedBox(height: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
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
      AssistantTab.voice => const VoiceChatPage(),
      AssistantTab.memory => const MemoryPage(showAppBar: false),
      AssistantTab.goals => const AccountabilityPage(showAppBar: false),
      AssistantTab.chats => ConversationListPage(
        showAppBar: false,
        onConversationSelected: onConversationSelected,
      ),
    };
  }
}
