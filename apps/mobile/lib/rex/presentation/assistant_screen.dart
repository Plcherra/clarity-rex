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
import 'rex_surfaces.dart';
import 'rex_ui_tokens.dart';
import 'widgets/assistant_proposal_settings_sheet.dart';

const _assistantCompactWidth = 360.0;
const _assistantTabHeight = 44.0;

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

    final isCompactWidth =
        MediaQuery.sizeOf(context).width < _assistantCompactWidth;
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
                  _AssistantTopSurface(
                    controller: _tabController,
                    isCompactWidth: isCompactWidth,
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

class _AssistantTopSurface extends StatelessWidget {
  const _AssistantTopSurface({
    required this.controller,
    required this.isCompactWidth,
    required this.profileController,
  });

  final TabController controller;
  final bool isCompactWidth;
  final ProfileController profileController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCompactWidth ? RexUiTokens.space12 : RexUiTokens.space16,
        RexUiTokens.space20,
        isCompactWidth ? RexUiTokens.space12 : RexUiTokens.space16,
        RexUiTokens.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.navAssistant,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: RexUiTokens.space12),
          _AssistantTabNavigation(
            controller: controller,
            isCompactWidth: isCompactWidth,
            profileController: profileController,
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
    required this.profileController,
  });

  final TabController controller;
  final bool isCompactWidth;
  final ProfileController profileController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.clarityColors;
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TabBar(
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
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            tabs: [
              for (final tab in AssistantTab.values)
                Tab(
                  key: tab.key,
                  height: _assistantTabHeight,
                  child: _AssistantTabItem(tab: tab),
                ),
            ],
          ),
        ),
        SizedBox(
          height: _assistantTabHeight,
          width: 52,
          child: Tooltip(
            message: l10n.assistantCompanionSettingsGearLabel,
            child: InkWell(
              onTap: () => showAssistantProposalSettingsSheet(
                context: context,
                profileController: profileController,
              ),
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(RexUiTokens.radiusSmall),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: scheme.onSurface.withValues(alpha: 0.78),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.assistantCompanionSettingsTabLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      label: tab.semanticLabelFor(context),
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
                  tab.labelFor(context),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: theme.textTheme.labelSmall?.copyWith(
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

  double _sidebarWidth = _defaultSidebarWidth;

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

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxAllowed = math.max(
          _minSidebarWidth,
          constraints.maxWidth * 0.45,
        );
        final width = _sidebarWidth
            .clamp(_minSidebarWidth, maxAllowed)
            .toDouble();
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
                child: ConversationListPage(
                  showAppBar: false,
                  compactSidebar: true,
                  onConversationSelected: widget.onConversationSelected,
                ),
              ),
            ),
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
