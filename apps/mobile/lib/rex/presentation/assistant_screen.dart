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
  TabController? _tabController;
  List<AssistantTab> _tabs = const [];
  String _selectedTabId = AssistantTab.chat.id;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTabController(assistantTabsOf(context));
  }

  void _syncTabController(List<AssistantTab> tabs) {
    final same =
        tabs.length == _tabs.length &&
        List.generate(tabs.length, (i) => tabs[i] == _tabs[i]).every((v) => v);
    if (same && _tabController != null) {
      return;
    }

    final previousId = _selectedTabId;
    final old = _tabController;
    if (old != null) {
      old.removeListener(_handleAssistantTabChanged);
      old.dispose();
    }

    final initialIndex = math.max(0, tabs.indexWhere((t) => t.id == previousId));
    final safeIndex = initialIndex >= 0 && initialIndex < tabs.length
        ? initialIndex
        : math.max(0, tabs.indexOf(AssistantTab.chat));

    _tabs = List<AssistantTab>.unmodifiable(tabs);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: safeIndex.clamp(0, _tabs.length - 1),
    )..addListener(_handleAssistantTabChanged);
    _selectedTabId = _tabs[_tabController!.index].id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateAssistantChatVisibility();
    });
  }

  void _handleAssistantTabChanged() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) {
      return;
    }
    _selectedTabId = _tabs[controller.index].id;
    _updateAssistantChatVisibility();
  }

  void _updateAssistantChatVisibility() {
    final controller = _tabController;
    if (controller == null || _tabs.isEmpty) {
      return;
    }
    final tab = _tabs[controller.index];
    ref.read(assistantChatVisibleProvider.notifier).setVisible(
      tab == AssistantTab.chat,
    );
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleAssistantTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _openTab(AssistantTab tab) {
    final controller = _tabController;
    if (controller == null) return;
    final index = _tabs.indexOf(tab);
    if (index < 0) return;
    controller.animateTo(index);
  }

  void _openChatTab() => _openTab(AssistantTab.chat);

  void _openKnowsTab() => _openTab(AssistantTab.memory);

  void _openGoalsTab() => _openTab(AssistantTab.goals);

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(assistantChatTabRequestProvider, (previous, next) {
      _openChatTab();
    });
    ref.listen<int>(assistantChatVisibilityResyncProvider, (previous, next) {
      _updateAssistantChatVisibility();
    });

    final controller = _tabController;
    if (controller == null || _tabs.isEmpty) {
      return const SizedBox.shrink();
    }

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
                    controller: controller,
                    tabs: _tabs,
                    profileController: widget.profileController,
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: controller,
                      children: [
                        for (final tab in _tabs)
                          _AssistantTabContent(
                            tab: tab,
                            wideSplit: wide,
                            profileController: widget.profileController,
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
    required this.profileController,
    required this.onConversationSelected,
    required this.onOpenKnows,
    required this.onOpenGoals,
  });

  final AssistantTab tab;
  final bool wideSplit;
  final ProfileController profileController;
  final VoidCallback onConversationSelected;
  final VoidCallback onOpenKnows;
  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      AssistantTab.chats => ConversationListPage(
        showAppBar: false,
        onConversationSelected: onConversationSelected,
      ),
      AssistantTab.chat => wideSplit
          ? _AssistantChatSplit(
              onConversationSelected: onConversationSelected,
              profileController: profileController,
            )
          : ChatPage(
              showAppBar: false,
              profileController: profileController,
            ),
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
  const _AssistantChatSplit({
    required this.onConversationSelected,
    required this.profileController,
  });

  final VoidCallback onConversationSelected;
  final ProfileController profileController;

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
            Expanded(
              child: ChatPage(
                showAppBar: false,
                profileController: widget.profileController,
              ),
            ),
          ],
        );
      },
    );
  }
}
