import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:clarity/rex/chat/application/conversation_controller.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';

class ConversationDateHeader extends StatelessWidget {
  const ConversationDateHeader({
    super.key,
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        RexUiTokens.space12,
        RexUiTokens.space16,
        RexUiTokens.space4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textMuted.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationHistoryTile extends StatefulWidget {
  const ConversationHistoryTile({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    this.onRename,
    this.compact = false,
  });

  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onRename;
  final bool compact;

  @override
  State<ConversationHistoryTile> createState() =>
      _ConversationHistoryTileState();
}

class _ConversationHistoryTileState extends State<ConversationHistoryTile> {
  bool _hovered = false;
  bool _menuOpen = false;

  bool get _showActions => !widget.compact || _hovered || _menuOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final preview = conversationPreview(l10n, widget.conversation);
    final title = conversationTitle(l10n, widget.conversation);
    final compact = widget.compact;
    final horizontal = compact ? RexUiTokens.space8 : RexUiTokens.space16;
    final vertical = compact ? 6.0 : RexUiTokens.space12;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, compact ? 2 : 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: widget.isSelected
              ? colors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            compact ? RexUiTokens.radiusSmall : RexUiTokens.radiusMedium,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(
              compact ? RexUiTokens.radiusSmall : RexUiTokens.radiusMedium,
            ),
            onTap: widget.onTap,
            onLongPress: widget.onDelete,
            mouseCursor: SystemMouseCursors.click,
            hoverColor: colors.accent.withValues(alpha: 0.08),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? RexUiTokens.space8 : RexUiTokens.space4,
                vertical: vertical,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!compact) ...[
                    _ConversationGlyph(isSelected: widget.isSelected),
                    const SizedBox(width: RexUiTokens.space12),
                  ],
                  Expanded(
                    child: compact
                        ? Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: widget.isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: RexUiTokens.space8),
                              Text(
                                timestampLabel(
                                  l10n,
                                  widget.conversation.timestamp,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: widget.isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: RexUiTokens.space8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 96,
                                    ),
                                    child: Text(
                                      timestampLabel(
                                        l10n,
                                        widget.conversation.timestamp,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: colors.textMuted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: RexUiTokens.space8),
                              Text(
                                preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (_showActions) ...[
                    const SizedBox(width: RexUiTokens.space4),
                    _ConversationMenu(
                      onDelete: widget.onDelete,
                      onRename: widget.onRename,
                      compact: compact,
                      onMenuOpenChanged: (open) {
                        setState(() => _menuOpen = open);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConversationSearchResultTile extends StatelessWidget {
  const ConversationSearchResultTile({
    super.key,
    required this.result,
    required this.onTap,
  });

  final ConversationSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final title = conversationSearchResultTitle(l10n, result);
    final timestamp = timestampLabel(
      l10n,
      result.message?.timestamp ?? result.conversationTimestamp,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        0,
        RexUiTokens.space16,
        RexUiTokens.space8,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RexUiTokens.space4,
            vertical: RexUiTokens.space12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.manage_search_rounded,
                color: colors.accent,
                size: 20,
              ),
              const SizedBox(width: RexUiTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: RexUiTokens.space8),
                        Text(
                          timestamp,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: RexUiTokens.space8),
                    Text(
                      result.preview.trim().isEmpty
                          ? l10n.conversationHistoryMatchedConversation
                          : result.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
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

class ConversationGroup {
  ConversationGroup({required this.label}) : conversations = [];

  final String label;
  final List<Conversation> conversations;
}

List<ConversationGroup> conversationGroups(
  AppLocalizations l10n,
  List<Conversation> conversations,
) {
  final now = DateTime.now();
  final groups = <ConversationGroup>[];
  final sorted = [...conversations]
    ..sort((a, b) {
      final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

  for (final conversation in sorted) {
    final label = conversationGroupLabel(l10n, conversation.timestamp, now);
    if (groups.isEmpty || groups.last.label != label) {
      groups.add(ConversationGroup(label: label));
    }
    groups.last.conversations.add(conversation);
  }

  return groups;
}

List<Conversation> filterConversationsByDate(
  List<Conversation> conversations,
  ConversationDateFilter filter, {
  DateTime? now,
}) {
  final range = conversationDateFilterRange(filter, now ?? DateTime.now());
  if (range == null) {
    return conversations;
  }

  return conversations
      .where((conversation) {
        final timestamp = conversation.timestamp;
        return timestamp != null && range.contains(timestamp);
      })
      .toList(growable: false);
}

List<ConversationSearchResult> filterConversationSearchResultsByDate(
  List<ConversationSearchResult> results,
  ConversationDateFilter filter, {
  DateTime? now,
}) {
  final range = conversationDateFilterRange(filter, now ?? DateTime.now());
  if (range == null) {
    return results;
  }

  return results
      .where((result) {
        final timestamp =
            result.message?.timestamp ?? result.conversationTimestamp;
        return timestamp != null && range.contains(timestamp);
      })
      .toList(growable: false);
}

DateTimeRange? conversationDateFilterRange(
  ConversationDateFilter filter,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (filter.type) {
    ConversationDateFilterType.all => null,
    ConversationDateFilterType.today => DateTimeRange(
      start: today,
      end: today.add(const Duration(days: 1)),
    ),
    ConversationDateFilterType.thisWeek => DateTimeRange(
      start: today.subtract(Duration(days: today.weekday - DateTime.monday)),
      end: today.add(const Duration(days: 1)),
    ),
    ConversationDateFilterType.thisMonth => DateTimeRange(
      start: DateTime(today.year, today.month),
      end: today.add(const Duration(days: 1)),
    ),
    ConversationDateFilterType.custom => _customDateFilterRange(filter),
  };
}

DateTimeRange? _customDateFilterRange(ConversationDateFilter filter) {
  final start = filter.start;
  final end = filter.end;
  if (start == null || end == null) {
    return null;
  }

  final normalizedStart = DateTime(start.year, start.month, start.day);
  final normalizedEnd = DateTime(end.year, end.month, end.day);
  if (normalizedEnd.isBefore(normalizedStart)) {
    return DateTimeRange(
      start: normalizedEnd,
      end: normalizedStart.add(const Duration(days: 1)),
    );
  }

  return DateTimeRange(
    start: normalizedStart,
    end: normalizedEnd.add(const Duration(days: 1)),
  );
}

extension on DateTimeRange {
  bool contains(DateTime timestamp) {
    final local = timestamp.toLocal();
    return !local.isBefore(start) && local.isBefore(end);
  }
}

String conversationDateFilterLabel(
  AppLocalizations l10n,
  ConversationDateFilter filter,
  DateTime now,
) {
  return switch (filter.type) {
    ConversationDateFilterType.all => l10n.commonAll,
    ConversationDateFilterType.today => l10n.commonToday,
    ConversationDateFilterType.thisWeek => l10n.commonThisWeek,
    ConversationDateFilterType.thisMonth => l10n.commonThisMonth,
    ConversationDateFilterType.custom => _customDateFilterChipLabel(l10n, filter),
  };
}

String _customDateFilterChipLabel(
  AppLocalizations l10n,
  ConversationDateFilter filter,
) {
  final startDate = filter.start;
  final endDate = filter.end;
  if (startDate == null || endDate == null) {
    return l10n.commonCustom;
  }

  final normalizedStart = DateTime(
    startDate.year,
    startDate.month,
    startDate.day,
  );
  final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);
  if (normalizedStart == normalizedEnd) {
    return l10n.conversationDateFilterCustomSingle(
      '${normalizedStart.month}/${normalizedStart.day}/${normalizedStart.year}',
    );
  }
  return l10n.conversationDateFilterCustomRange(
    '${normalizedStart.month}/${normalizedStart.day}',
    '${normalizedEnd.month}/${normalizedEnd.day}',
  );
}

String conversationTitle(AppLocalizations l10n, Conversation conversation) {
  final title = conversation.title?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }

  final preview = conversation.lastMessage?.content.trim();
  if (preview != null && preview.isNotEmpty) {
    return preview;
  }

  return l10n.conversationHistoryNewConversation;
}

String conversationSearchResultTitle(
  AppLocalizations l10n,
  ConversationSearchResult result,
) {
  final title = result.conversationTitle?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }

  final message = result.message?.content.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }

  return l10n.commonConversation;
}

String timestampLabel(AppLocalizations l10n, DateTime? timestamp) {
  if (timestamp == null) {
    return '';
  }

  final local = timestamp.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  if (date == today) {
    return '$hour:$minute';
  }
  if (date.year == today.year) {
    return '${localizedShortMonthName(l10n, local.month)} ${local.day}';
  }
  return '${localizedShortMonthName(l10n, local.month)} ${local.day}, ${local.year}';
}

String conversationGroupLabel(
  AppLocalizations l10n,
  DateTime? timestamp,
  DateTime now,
) {
  if (timestamp == null) {
    return l10n.commonUndated;
  }

  final local = timestamp.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final dayDifference = today.difference(date).inDays;

  if (dayDifference < 0) {
    return l10n.commonUpcoming;
  }
  if (dayDifference == 0) {
    return l10n.commonToday;
  }
  if (dayDifference == 1) {
    return l10n.commonYesterday;
  }
  if (dayDifference < 7) {
    return l10n.commonThisWeek;
  }
  return l10n.commonMonthYear(
    localizedMonthName(l10n, local.month),
    local.year.toString(),
  );
}

String conversationPreview(AppLocalizations l10n, Conversation conversation) {
  final preview = conversation.lastMessage?.content.trim();
  if (preview != null && preview.isNotEmpty) {
    return preview;
  }
  return l10n.conversationHistoryNoMessagesYet;
}

String localizedMonthName(AppLocalizations l10n, int month) {
  return switch (month) {
    DateTime.january => l10n.commonMonthJanuary,
    DateTime.february => l10n.commonMonthFebruary,
    DateTime.march => l10n.commonMonthMarch,
    DateTime.april => l10n.commonMonthApril,
    DateTime.may => l10n.commonMonthMay,
    DateTime.june => l10n.commonMonthJune,
    DateTime.july => l10n.commonMonthJuly,
    DateTime.august => l10n.commonMonthAugust,
    DateTime.september => l10n.commonMonthSeptember,
    DateTime.october => l10n.commonMonthOctober,
    DateTime.november => l10n.commonMonthNovember,
    DateTime.december => l10n.commonMonthDecember,
    _ => l10n.commonOlder,
  };
}

String localizedShortMonthName(AppLocalizations l10n, int month) {
  return switch (month) {
    DateTime.january => l10n.commonMonthShortJan,
    DateTime.february => l10n.commonMonthShortFeb,
    DateTime.march => l10n.commonMonthShortMar,
    DateTime.april => l10n.commonMonthShortApr,
    DateTime.may => l10n.commonMonthShortMay,
    DateTime.june => l10n.commonMonthShortJun,
    DateTime.july => l10n.commonMonthShortJul,
    DateTime.august => l10n.commonMonthShortAug,
    DateTime.september => l10n.commonMonthShortSep,
    DateTime.october => l10n.commonMonthShortOct,
    DateTime.november => l10n.commonMonthShortNov,
    DateTime.december => l10n.commonMonthShortDec,
    _ => l10n.commonMonthShortOld,
  };
}

class _ConversationGlyph extends StatelessWidget {
  const _ConversationGlyph({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return Icon(
      Icons.chat_bubble_outline_rounded,
      color: isSelected ? colors.accent : colors.textMuted,
      size: 20,
    );
  }
}

class _ConversationMenu extends StatelessWidget {
  const _ConversationMenu({
    required this.onDelete,
    this.onRename,
    this.compact = false,
    this.onMenuOpenChanged,
  });

  final VoidCallback onDelete;
  final VoidCallback? onRename;
  final bool compact;
  final ValueChanged<bool>? onMenuOpenChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    if (onRename == null) {
      return IconButton(
        tooltip: l10n.commonDelete,
        mouseCursor: SystemMouseCursors.click,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: compact ? 32 : 36,
          minHeight: compact ? 32 : 36,
        ),
        onPressed: onDelete,
        icon: Icon(
          Icons.delete_outline_rounded,
          size: compact ? 16 : 18,
          color: colors.textMuted,
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: l10n.conversationHistoryActionsTooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: compact ? 32 : 36,
        minHeight: compact ? 32 : 36,
      ),
      icon: Icon(
        Icons.more_vert_rounded,
        size: compact ? 16 : 18,
        color: colors.textMuted,
      ),
      onOpened: () => onMenuOpenChanged?.call(true),
      onCanceled: () => onMenuOpenChanged?.call(false),
      onSelected: (value) {
        onMenuOpenChanged?.call(false);
        if (value == 'rename') {
          onRename!();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'rename',
          child: Text(l10n.commonRename),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }
}
