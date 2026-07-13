import 'package:flutter/material.dart';

import '../../core/layout/clarity_breakpoints.dart';
import '../../core/layout/clarity_native_layout.dart';
import '../../core/l10n/app_l10n.dart';
import '../../features/profile/application/profile_controller.dart';
import '../../theme/clarity_colors.dart';
import 'assistant_tab.dart';
import 'rex_ui_tokens.dart';
import 'widgets/assistant_proposal_settings_sheet.dart';

/// Compact phone chrome vs slightly roomier wide `/app/` header.
double assistantTabBarHeightOf(BuildContext context) {
  return RexUiTokens.isCompactChrome(context) ? 40.0 : 44.0;
}

class AssistantTopSurface extends StatelessWidget {
  const AssistantTopSurface({
    super.key,
    required this.controller,
    required this.tabs,
    required this.profileController,
  });

  final TabController controller;
  final List<AssistantTab> tabs;
  final ProfileController profileController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = RexUiTokens.isCompactChrome(context);
    final nativeCompact = RexUiTokens.isNativeCompactChrome(context);
    final showTitle = RexUiTokens.showsAssistantPageTitle(context);
    final horizontal = nativeCompact
        ? ClarityNativeLayout.pageGutter(context)
        : compact
        ? RexUiTokens.space8
        : RexUiTokens.space16;
    final top = nativeCompact
        ? RexUiTokens.space4
        : compact
        ? RexUiTokens.space8
        : RexUiTokens.space20;
    final titleGap = compact ? RexUiTokens.space8 : RexUiTokens.space12;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        top,
        horizontal,
        RexUiTokens.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text(
              context.l10n.navAssistant,
              style: (compact
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.titleLarge)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                height: 1.1,
              ),
            ),
            SizedBox(height: titleGap),
          ],
          AssistantTabNavigation(
            controller: controller,
            tabs: tabs,
            profileController: profileController,
          ),
        ],
      ),
    );
  }
}

class AssistantTabNavigation extends StatelessWidget {
  const AssistantTabNavigation({
    super.key,
    required this.controller,
    required this.tabs,
    required this.profileController,
  });

  final TabController controller;
  final List<AssistantTab> tabs;
  final ProfileController profileController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final tabHeight = assistantTabBarHeightOf(context);
    final compact = RexUiTokens.isCompactChrome(context);
    final settingsWidth = compact ? 44.0 : 52.0;

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
              insets: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
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
              for (final tab in tabs)
                Tab(
                  key: tab.key,
                  height: tabHeight,
                  child: AssistantTabItem(tab: tab),
                ),
            ],
          ),
        ),
        SizedBox(
          height: tabHeight,
          width: settingsWidth,
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
                    size: compact ? 18 : 20,
                    color: scheme.onSurface.withValues(alpha: 0.78),
                  ),
                  if (!compact) ...[
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AssistantTabItem extends StatelessWidget {
  const AssistantTabItem({super.key, required this.tab});

  final AssistantTab tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = RexUiTokens.isCompactChrome(context);
    final nativeCompact = RexUiTokens.isNativeCompactChrome(context);

    return Semantics(
      label: tab.semanticLabelFor(context),
      button: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: compact ? 18 : 20),
            SizedBox(height: compact ? 1 : 2),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.labelFor(context),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    // Native phone: keep theme labelSmall (avoid forced 11px crush).
                    fontSize: compact && !nativeCompact ? 11 : null,
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

/// Kept for call sites that previously used the local compact-width heuristic.
bool assistantUsesNarrowTabLabels(BuildContext context) {
  return MediaQuery.sizeOf(context).width < 360 ||
      !isClarityDesktopLayout(context);
}
