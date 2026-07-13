import '../../../../l10n/app_localizations.dart';
import 'package:clarity/rex/chat/application/conversation_controller.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:flutter/material.dart';

import 'conversation_history_labels.dart';

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
