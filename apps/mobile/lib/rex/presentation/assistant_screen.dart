import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/clarity_breakpoints.dart';
import '../../core/l10n/app_l10n.dart';
import '../../features/profile/application/profile_controller.dart';
import '../accountability/presentation/pages/accountability_page.dart';
import '../chat/presentation/pages/chat_page.dart';
import '../chat/presentation/pages/conversation_list_page.dart';
import '../memory/presentation/pages/memory_page.dart';
import 'assistant_chat_visible_provider.dart';
import '../../theme/clarity_colors.dart';
import 'assistant_overview_page.dart';
import 'assistant_tab.dart';
import 'assistant_top_surface.dart';
import 'rex_surfaces.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, required this.profileController});

  final ProfileController profileController;

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
    _tabController.addListener(_handleAssistantTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateAssistantChatVisibility();
    });
  }

  void _handleAssistantTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    _updateAssistantChatVisibility();
  }

  void _updateAssistantChatVisibility() {
    ref.read(assistantChatVisibleProvider.notifier).setVisible(
      _tabController.index == AssistantTab.chat.index,
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleAssistantTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _openChatTab() {
    _tabController.animateTo(AssistantTab.chat.index);
  }

  void _openKnowsTab() {
    _tabController.animateTo(AssistantTab.memory.index);
  }

  void _openGoalsTab() {
    _tabController.animateTo(AssistantTab.goals.index);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(assistantChatTabRequestProvider, (previous, next) {
      if (_tabController.index == AssistantTab.chat.index) {
        return;
      }
      _tabController.animateTo(AssistantTab.chat.index);
    });
    ref.listen<int>(assistantChatVisibilityResyncProvider, (previous, next) {
      _updateAssistantChatVisibility();
    });

    final wide = isClarityWideLayout(context);

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
                  AssistantTopSurface(
                    controller: _tabController,
                    profileController: widget.profileController,
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        for (final tab in AssistantTab.values)
                          _AssistantTabContent(
                            tab: tab,
                            wideSplit: wide,
                            onConversationSelected: _openChatTab,
                            onOpenKnows: _openKnowsTab,
                            onOpenGoals: _openGoalsTab,
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

class _AssistantTabContent extends StatelessWidget {
  const _AssistantTabContent({
    required this.tab,
    required this.wideSplit,
    required this.onConversationSelected,
    required this.onOpenKnows,
    required this.onOpenGoals,
  });

  final AssistantTab tab;
  final bool wideSplit;
  final VoidCallback onConversationSelected;
  final VoidCallback onOpenKnows;
  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      AssistantTab.chat => wideSplit
          ? _AssistantChatSplit(onConversationSelected: onConversationSelected)
          : const ChatPage(showAppBar: false),
      AssistantTab.memory => const MemoryPage(showAppBar: false),
      AssistantTab.goals => const AccountabilityPage(showAppBar: false),
      AssistantTab.overview => AssistantOverviewPage(
        key: const ValueKey<String>('assistant-overview-page'),
        onOpenChat: onConversationSelected,
        onOpenKnows: onOpenKnows,
        onOpenGoals: onOpenGoals,
      ),
    };
  }
}

class _AssistantChatSplit extends StatefulWidget {
  const _AssistantChatSplit({required this.onConversationSelected});

  final VoidCallback onConversationSelected;

  @override
  State<_AssistantChatSplit> createState() => _AssistantChatSplitState();
}

class _AssistantChatSplitState extends State<_AssistantChatSplit> {
  static const double _defaultSidebarWidth = 340;
  static const double _minSidebarWidth = 240;
  static const double _maxSidebarWidth = 520;
  static const double _collapsedRailWidth = 44;

  double _sidebarWidth = _defaultSidebarWidth;
  bool _sidebarCollapsed = false;

  void _resizeSidebar(double delta, double maxAllowed) {
    final next = (_sidebarWidth + delta).clamp(
      _minSidebarWidth,
      math.min(_maxSidebarWidth, maxAllowed),
    ).toDouble();
    if (next == _sidebarWidth) {
      return;
    }
    setState(() => _sidebarWidth = next);
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxAllowed = math.max(
          _minSidebarWidth,
          constraints.maxWidth * 0.45,
        );
        final width = _sidebarCollapsed
            ? _collapsedRailWidth
            : _sidebarWidth.clamp(_minSidebarWidth, maxAllowed).toDouble();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: width,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.55),
                  border: Border(
                    right: BorderSide(
                      color: colors.border.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                child: _sidebarCollapsed
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: IconButton(
                            tooltip: l10n.assistantChatSidebarShowTooltip,
                            onPressed: _toggleSidebar,
                            icon: const Icon(Icons.view_sidebar_outlined),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: l10n.assistantChatSidebarHideTooltip,
                              onPressed: _toggleSidebar,
                              icon: const Icon(Icons.view_sidebar),
                            ),
                          ),
                          Expanded(
                            child: ConversationListPage(
                              showAppBar: false,
                              compactSidebar: true,
                              onConversationSelected:
                                  widget.onConversationSelected,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (!_sidebarCollapsed)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    _resizeSidebar(details.delta.dx, maxAllowed);
                  },
                  child: SizedBox(
                    width: 8,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: double.infinity,
                        color: colors.border.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
              ),
            const Expanded(
              child: ChatPage(showAppBar: false),
            ),
          ],
        );
      },
    );
  }
}
