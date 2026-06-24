import 'package:flutter/material.dart';

import 'package:clarity/rex/chat/application/conversation_controller.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
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
        RexUiTokens.space24,
        RexUiTokens.space20,
        RexUiTokens.space24,
        RexUiTokens.space8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textMuted.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationHistoryTile extends StatelessWidget {
  const ConversationHistoryTile({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final preview = _conversationPreview(conversation);

    return RexSurface(
      margin: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        0,
        RexUiTokens.space16,
        RexUiTokens.space12,
      ),
      padding: EdgeInsets.zero,
      color: isSelected
          ? colors.accent.withValues(alpha: 0.10)
          : Colors.transparent,
      radius: RexUiTokens.radiusLarge,
      child: InkWell(
        borderRadius: BorderRadius.circular(RexUiTokens.radiusLarge),
        onTap: onTap,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(RexUiTokens.space16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConversationGlyph(isSelected: isSelected),
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
                            conversationTitle(conversation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: RexUiTokens.space8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 96),
                          child: Text(
                            timestampLabel(conversation.timestamp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.labelSmall?.copyWith(
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
              const SizedBox(width: RexUiTokens.space4),
              _ConversationMenu(onDelete: onDelete),
            ],
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
    final title = _searchResultTitle(result);
    final timestamp = timestampLabel(
      result.message?.timestamp ?? result.conversationTimestamp,
    );

    return RexSurface(
      margin: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        0,
        RexUiTokens.space16,
        RexUiTokens.space12,
      ),
      padding: EdgeInsets.zero,
      color: colors.surface.withValues(alpha: 0.64),
      radius: RexUiTokens.radiusLarge,
      child: InkWell(
        borderRadius: BorderRadius.circular(RexUiTokens.radiusLarge),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(RexUiTokens.space16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
                ),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.manage_search_rounded,
                    color: colors.accent,
                    size: 23,
                  ),
                ),
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
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w800,
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
                          ? 'Matched conversation'
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

List<ConversationGroup> conversationGroups(List<Conversation> conversations) {
  final now = DateTime.now();
  final groups = <ConversationGroup>[];
  final sorted = [...conversations]
    ..sort((a, b) {
      final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

  for (final conversation in sorted) {
    final label = conversationGroupLabel(conversation.timestamp, now);
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

String conversationTitle(Conversation conversation) {
  final title = conversation.title?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }

  final preview = conversation.lastMessage?.content.trim();
  if (preview != null && preview.isNotEmpty) {
    return preview;
  }

  return 'New conversation';
}

String _searchResultTitle(ConversationSearchResult result) {
  final title = result.conversationTitle?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }

  final message = result.message?.content.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }

  return 'Conversation';
}

String timestampLabel(DateTime? timestamp) {
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
    return '${_shortMonthName(local.month)} ${local.day}';
  }
  return '${_shortMonthName(local.month)} ${local.day}, ${local.year}';
}

String conversationGroupLabel(DateTime? timestamp, DateTime now) {
  if (timestamp == null) {
    return 'Undated';
  }

  final local = timestamp.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final dayDifference = today.difference(date).inDays;

  if (dayDifference < 0) {
    return 'Upcoming';
  }
  if (dayDifference == 0) {
    return 'Today';
  }
  if (dayDifference == 1) {
    return 'Yesterday';
  }
  if (dayDifference < 7) {
    return 'This week';
  }
  return '${_monthName(local.month)} ${local.year}';
}

String _conversationPreview(Conversation conversation) {
  final preview = conversation.lastMessage?.content.trim();
  if (preview != null && preview.isNotEmpty) {
    return preview;
  }
  return 'No messages yet';
}

String _monthName(int month) {
  return switch (month) {
    DateTime.january => 'January',
    DateTime.february => 'February',
    DateTime.march => 'March',
    DateTime.april => 'April',
    DateTime.may => 'May',
    DateTime.june => 'June',
    DateTime.july => 'July',
    DateTime.august => 'August',
    DateTime.september => 'September',
    DateTime.october => 'October',
    DateTime.november => 'November',
    DateTime.december => 'December',
    _ => 'Older',
  };
}

String _shortMonthName(int month) {
  return switch (month) {
    DateTime.january => 'Jan',
    DateTime.february => 'Feb',
    DateTime.march => 'Mar',
    DateTime.april => 'Apr',
    DateTime.may => 'May',
    DateTime.june => 'Jun',
    DateTime.july => 'Jul',
    DateTime.august => 'Aug',
    DateTime.september => 'Sep',
    DateTime.october => 'Oct',
    DateTime.november => 'Nov',
    DateTime.december => 'Dec',
    _ => 'Old',
  };
}

class _ConversationGlyph extends StatelessWidget {
  const _ConversationGlyph({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected
            ? colors.accent.withValues(alpha: 0.14)
            : colors.surfaceElevated.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
      ),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(
          Icons.chat_bubble_outline_rounded,
          color: colors.accent,
          size: 20,
        ),
      ),
    );
  }
}

class _ConversationMenu extends StatelessWidget {
  const _ConversationMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return PopupMenuButton<_ConversationAction>(
      tooltip: 'Conversation actions',
      color: colors.surfaceElevated,
      iconColor: colors.textMuted,
      onSelected: (action) {
        switch (action) {
          case _ConversationAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ConversationAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: colors.danger),
              const SizedBox(width: RexUiTokens.space12),
              Text(
                'Delete',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ConversationAction { delete }
