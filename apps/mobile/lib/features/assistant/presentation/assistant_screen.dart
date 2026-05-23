import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../accountability/presentation/pages/accountability_page.dart';
import '../chat/presentation/pages/chat_page.dart';
import '../chat/presentation/pages/conversation_list_page.dart';
import '../memory/presentation/pages/memory_page.dart';
import '../voice/presentation/pages/voice_call_page.dart';

class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key, required this.ui});

  final AppUiDependencies ui;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Assistant'),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const ConversationListPage(),
                  ),
                );
              },
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Conversations',
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                labelColor: scheme.onSurface,
                unselectedLabelColor: scheme.onSurfaceVariant,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
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
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            ChatPage(showAppBar: false),
            VoiceCallPage(
              autoStart: false,
              showAppBar: false,
              closeOnEnd: false,
            ),
            MemoryPage(showAppBar: false),
            AccountabilityPage(showAppBar: false),
          ],
        ),
      ),
    );
  }
}
