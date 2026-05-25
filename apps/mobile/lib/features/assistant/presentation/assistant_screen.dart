import 'package:flutter/material.dart';

import '../accountability/presentation/pages/accountability_page.dart';
import '../chat/presentation/pages/chat_page.dart';
import '../chat/presentation/pages/conversation_list_page.dart';
import '../memory/presentation/pages/memory_page.dart';

const _assistantChatTabIndex = 0;

class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.9,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    labelColor: scheme.onSurface,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    padding: EdgeInsets.zero,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.chat_bubble_outline_rounded),
                        text: 'Chat',
                      ),
                      Tab(icon: Icon(Icons.graphic_eq_rounded), text: 'Voice'),
                      Tab(
                        icon: Icon(Icons.psychology_alt_outlined),
                        text: 'Memory',
                      ),
                      Tab(icon: Icon(Icons.flag_outlined), text: 'Goals'),
                      Tab(icon: Icon(Icons.forum_outlined), text: 'Chats'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    const ChatPage(showAppBar: false),
                    const ChatPage(showAppBar: false),
                    const MemoryPage(showAppBar: false),
                    const AccountabilityPage(showAppBar: false),
                    Builder(
                      builder: (context) => ConversationListPage(
                        showAppBar: false,
                        onConversationSelected: () {
                          DefaultTabController.of(
                            context,
                          ).animateTo(_assistantChatTabIndex);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
