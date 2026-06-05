import 'package:flutter/material.dart';

import 'package:clarity/features/assistant/chat/data/chat_models.dart';
import 'package:clarity/features/assistant/presentation/rex_surfaces.dart';
import 'package:clarity/features/assistant/presentation/rex_ui_tokens.dart';

class ConversationDateHeader extends StatelessWidget {
  const ConversationDateHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RexUiTokens.space24,
        RexUiTokens.space20,
        RexUiTokens.space24,
        RexUiTokens.space8,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: RexUiTokens.textSubtle,
          fontWeight: FontWeight.w800,
        ),
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
    final preview = _conversationPreview(conversation);

    return RexSurface(
      margin: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        0,
        RexUiTokens.space16,
        RexUiTokens.space12,
      ),
      padding: EdgeInsets.zero,
      color: isSelected ? RexUiTokens.surfaceRaised : RexUiTokens.surface,
      borderColor: isSelected ? RexUiTokens.accent : RexUiTokens.border,
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
                              color: RexUiTokens.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: RexUiTokens.space8),
                        Text(
                          timestampLabel(conversation.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: RexUiTokens.textSubtle,
                            fontWeight: FontWeight.w700,
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
                        color: RexUiTokens.textMuted,
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

class ConversationGroup {
  ConversationGroup({required this.label}) : conversations = [];

  final String label;
  final List<Conversation> conversations;
}

List<ConversationGroup> conversationGroups(List<Conversation> conversations) {
  final now = DateTime.now();
  final groups = <ConversationGroup>[];

  for (final conversation in conversations) {
    final label = conversationDateLabel(conversation.timestamp, now);
    if (groups.isEmpty || groups.last.label != label) {
      groups.add(ConversationGroup(label: label));
    }
    groups.last.conversations.add(conversation);
  }

  return groups;
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

String timestampLabel(DateTime? timestamp) {
  if (timestamp == null) {
    return '';
  }

  final local = timestamp.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String conversationDateLabel(DateTime? timestamp, DateTime now) {
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
    return _weekdayName(local.weekday);
  }

  return '${_monthName(local.month)} ${local.day}, ${local.year}';
}

String _conversationPreview(Conversation conversation) {
  final preview = conversation.lastMessage?.content.trim();
  if (preview != null && preview.isNotEmpty) {
    return preview;
  }
  return 'No messages yet';
}

String _weekdayName(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => 'Older',
  };
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

class _ConversationGlyph extends StatelessWidget {
  const _ConversationGlyph({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected
            ? RexUiTokens.accent.withValues(alpha: 0.18)
            : RexUiTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
        border: Border.all(
          color: isSelected
              ? RexUiTokens.accent.withValues(alpha: 0.7)
              : RexUiTokens.border,
        ),
      ),
      child: const SizedBox(
        width: 42,
        height: 42,
        child: Icon(
          Icons.chat_bubble_outline_rounded,
          color: RexUiTokens.accent,
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
    return PopupMenuButton<_ConversationAction>(
      tooltip: 'Conversation actions',
      color: RexUiTokens.surfaceRaised,
      iconColor: RexUiTokens.textSubtle,
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
              const Icon(
                Icons.delete_outline_rounded,
                color: RexUiTokens.danger,
              ),
              const SizedBox(width: RexUiTokens.space12),
              Text(
                'Delete',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RexUiTokens.text,
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
