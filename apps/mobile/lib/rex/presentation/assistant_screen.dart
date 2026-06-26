import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accountability/presentation/pages/accountability_page.dart';
import '../chat/presentation/pages/chat_page.dart';
import '../chat/presentation/pages/conversation_list_page.dart';
import '../memory/presentation/pages/memory_page.dart';
import '../../theme/clarity_colors.dart';
import 'assistant_tab.dart';
import 'rex_surfaces.dart';
import 'rex_ui_tokens.dart';

const _assistantCompactWidth = 360.0;
const _assistantTabHeight = 46.0;

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
    final isCompactWidth =
        MediaQuery.sizeOf(context).width < _assistantCompactWidth;

    return RexTheme(
      child: Builder(
        builder: (context) {
          final colors = context.clarityColors;
          return Scaffold(
            backgroundColor: colors.background,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              top: true,
              bottom: false,
              child: Column(
                children: [
                  _AssistantTopSurface(
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
        },
      ),
    );
  }
}

class _AssistantTopSurface extends StatelessWidget {
  const _AssistantTopSurface({
    required this.controller,
    required this.isCompactWidth,
  });

  final TabController controller;
  final bool isCompactWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.clarityColors;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCompactWidth ? 12 : 16,
        isCompactWidth ? 4 : 8,
        isCompactWidth ? 12 : 16,
        isCompactWidth ? 4 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assistant',
            style:
                (isCompactWidth
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleLarge)
                    ?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                      height: 1.05,
                    ),
          ),
          SizedBox(
            height: isCompactWidth ? RexUiTokens.space8 : RexUiTokens.space12,
          ),
          _AssistantTabNavigation(
            controller: controller,
            isCompactWidth: isCompactWidth,
          ),
        ],
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
    final colors = context.clarityColors;

    return TabBar(
      controller: controller,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: colors.accent, width: 2),
        insets: const EdgeInsets.symmetric(horizontal: 8),
      ),
      labelColor: scheme.onSurface,
      unselectedLabelColor: colors.textMuted,
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      tabs: [
        for (final tab in AssistantTab.values)
          Tab(
            key: tab.key,
            height: _assistantTabHeight,
            child: _AssistantTabItem(tab: tab),
          ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 20),
            const SizedBox(height: 2),
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
      AssistantTab.memory => const MemoryPage(showAppBar: false),
      AssistantTab.goals => const AccountabilityPage(showAppBar: false),
      AssistantTab.chats => ConversationListPage(
        showAppBar: false,
        onConversationSelected: onConversationSelected,
      ),
    };
  }
}
