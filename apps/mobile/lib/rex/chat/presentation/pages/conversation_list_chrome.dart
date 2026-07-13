import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/rex/chat/application/conversation_controller.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/chat/presentation/widgets/conversation_history_widgets.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

/// Shared horizontal inset for Chats search chrome and history rows.
double conversationListHorizontalInset(
  BuildContext context, {
  required bool compactSidebar,
}) {
  if (ClarityNativeLayout.active(context)) {
    return ClarityNativeLayout.listRowPadding(context).left;
  }
  return compactSidebar ? 12.0 : 16.0;
}

class ConversationListSearchField extends StatelessWidget {
  const ConversationListSearchField({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final native = ClarityNativeLayout.active(context);
    final textStyle = (native ? theme.textTheme.bodySmall : theme.textTheme.bodyLarge)
        ?.copyWith(color: colors.textPrimary);
    final hintStyle = (native ? theme.textTheme.bodySmall : theme.textTheme.bodyLarge)
        ?.copyWith(color: colors.textMuted);

    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: textStyle,
      cursorColor: colors.accent,
      decoration: InputDecoration(
        hintText: l10n.conversationListSearchHint,
        hintStyle: hintStyle,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: native ? 18 : 24,
          color: colors.textSecondary,
        ),
        prefixIconConstraints: native
            ? const BoxConstraints(minWidth: 36, minHeight: 36)
            : null,
        suffixIcon: isSearching
            ? Padding(
                padding: EdgeInsets.all(native ? 10 : 14),
                child: const ClarityInlineLoader(size: 18, strokeWidth: 2),
              )
            : IconButton(
                tooltip: l10n.conversationListClearSearchTooltip,
                onPressed: onClear,
                iconSize: native ? 18 : 24,
                visualDensity: native
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                icon: const Icon(Icons.close_rounded),
                color: colors.textSecondary,
              ),
        filled: true,
        fillColor: colors.surface,
        isDense: native,
        contentPadding: native
            ? const EdgeInsets.symmetric(
                horizontal: RexUiTokens.space8,
                vertical: RexUiTokens.space4,
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
          borderSide: BorderSide(color: colors.borderActive, width: 1.2),
        ),
      ),
    );
  }
}

class ConversationListSearchResultsSliver extends StatelessWidget {
  const ConversationListSearchResultsSliver({
    super.key,
    required this.state,
    required this.results,
    required this.onResultTap,
  });

  final ConversationListState state;
  final List<ConversationSearchResult> results;
  final ValueChanged<ConversationSearchResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    if (state.isSearching && state.searchResults.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: ClarityPathLoader(
            size: 48,
            label: l10n.conversationListSearching,
          ),
        ),
      );
    }

    if (results.isEmpty) {
      final suffix = state.dateFilter.isActive
          ? l10n.conversationListNoMatchesSuffixInFilter(
              conversationDateFilterLabel(
                l10n,
                state.dateFilter,
                DateTime.now(),
              ).toLowerCase(),
            )
          : '';
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: RexSurface(
              padding: const EdgeInsets.all(RexUiTokens.space20),
              color: colors.surface.withValues(alpha: 0.82),
              radius: RexUiTokens.radiusLarge,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: colors.accent,
                    size: 30,
                  ),
                  const SizedBox(height: RexUiTokens.space12),
                  Text(
                    l10n.conversationListNoMatchesTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: RexUiTokens.space4),
                  Text(
                    l10n.conversationListNoMatchesBody(
                      state.searchQuery,
                      suffix,
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final result = results[index];
        return ConversationSearchResultTile(
          result: result,
          onTap: () => onResultTap(result),
        );
      }, childCount: results.length),
    );
  }
}

class ConversationListDateFilters extends StatelessWidget {
  const ConversationListDateFilters({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.onCustomTap,
  });

  final ConversationDateFilter filter;
  final ValueChanged<ConversationDateFilter> onFilterChanged;
  final VoidCallback onCustomTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final chips = <Widget>[
      ConversationListFilterChip(
        label: l10n.commonAll,
        selected: filter.type == ConversationDateFilterType.all,
        onTap: () => onFilterChanged(const ConversationDateFilter.all()),
      ),
      ConversationListFilterChip(
        label: l10n.commonToday,
        selected: filter.type == ConversationDateFilterType.today,
        onTap: () => onFilterChanged(const ConversationDateFilter.today()),
      ),
      ConversationListFilterChip(
        label: l10n.commonThisWeek,
        selected: filter.type == ConversationDateFilterType.thisWeek,
        onTap: () => onFilterChanged(const ConversationDateFilter.thisWeek()),
      ),
      ConversationListFilterChip(
        label: l10n.commonThisMonth,
        selected: filter.type == ConversationDateFilterType.thisMonth,
        onTap: () => onFilterChanged(const ConversationDateFilter.thisMonth()),
      ),
      ConversationListFilterChip(
        label: filter.type == ConversationDateFilterType.custom
            ? conversationDateFilterLabel(l10n, filter, now)
            : l10n.commonCustom,
        icon: Icons.calendar_month_rounded,
        selected: filter.type == ConversationDateFilterType.custom,
        onTap: onCustomTap,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }
}

class ConversationListFilterChip extends StatelessWidget {
  const ConversationListFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final native = ClarityNativeLayout.active(context);
    final foreground = selected
        ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white)
        : colors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: RexUiTokens.space8),
      child: ActionChip(
        avatar: icon == null
            ? null
            : Icon(icon, size: native ? 14 : 16, color: foreground),
        label: Text(label),
        labelStyle: (native ? theme.textTheme.labelSmall : theme.textTheme.labelLarge)
            ?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
        backgroundColor: selected
            ? colors.accent
            : colors.surfaceElevated.withValues(alpha: 0.72),
        visualDensity: native
            ? const VisualDensity(horizontal: 0, vertical: -2)
            : VisualDensity.standard,
        materialTapTargetSize: native
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        labelPadding: native
            ? const EdgeInsets.symmetric(horizontal: 8)
            : null,
        padding: native ? EdgeInsets.zero : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
        ),
        side: BorderSide.none,
        onPressed: onTap,
      ),
    );
  }
}

class ConversationListEmptyState extends StatelessWidget {
  const ConversationListEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.isLoading,
    required this.onNewConversation,
  });

  final String title;
  final String message;
  final bool isLoading;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final compact = MediaQuery.sizeOf(context).height < 650;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          compact ? RexUiTokens.space12 : RexUiTokens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Icon(Icons.forum_outlined, color: colors.accent, size: 28),
              const SizedBox(height: RexUiTokens.space12),
            ],
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? RexUiTokens.space4 : RexUiTokens.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.25,
                fontSize: 14,
              ),
            ),
            SizedBox(
              height: compact ? RexUiTokens.space12 : RexUiTokens.space16,
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onPressed: isLoading ? null : onNewConversation,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.l10n.conversationListNewChat),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationListErrorBanner extends StatelessWidget {
  const ConversationListErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return RexSurface(
      padding: const EdgeInsets.all(RexUiTokens.space16),
      color: colors.danger.withValues(alpha: 0.12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.danger, size: 20),
          const SizedBox(width: RexUiTokens.space12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
