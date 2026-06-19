import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/rex/chat/application/conversation_controller.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/chat/presentation/widgets/conversation_history_widgets.dart';

void main() {
  group('conversationGroups', () {
    test(
      'sorts conversations newest first and groups them by useful sections',
      () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 12);
        final yesterday = today.subtract(const Duration(days: 1));
        final thisWeek = today.subtract(const Duration(days: 3));
        final older = now.month == 1
            ? DateTime(now.year - 1, 12, 8)
            : DateTime(now.year, now.month - 1, 8);

        final groups = conversationGroups([
          _conversation('older', older),
          _conversation('today-late', today.add(const Duration(hours: 2))),
          _conversation('this-week', thisWeek),
          _conversation('today-early', today),
          _conversation('yesterday', yesterday),
        ]);

        expect(groups.map((group) => group.label), [
          'Today',
          'Yesterday',
          'This week',
          conversationGroupLabel(older, now),
        ]);
        expect(
          groups.first.conversations.map((conversation) => conversation.id),
          ['today-late', 'today-early'],
        );
        expect(groups.first.conversations.length, 2);
      },
    );

    test('keeps undated conversations in their own section', () {
      final groups = conversationGroups([
        _conversation('dated', DateTime.now()),
        _conversation('undated', null),
      ]);

      expect(groups.last.label, 'Undated');
      expect(groups.last.conversations.single.id, 'undated');
    });
  });

  group('conversationGroupLabel', () {
    test('uses month and year labels for older chats', () {
      final now = DateTime(2026, 6, 18);
      final timestamp = DateTime(2025, 11, 4);

      expect(conversationGroupLabel(timestamp, now), 'November 2025');
    });
  });

  group('timestampLabel', () {
    test('uses time for today and dates for older chats', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 9, 5);
      final sameYear = DateTime(now.year, now.month == 1 ? 12 : 1, 15, 9, 5);
      final previousYear = DateTime(now.year - 1, 11, 4, 9, 5);

      expect(timestampLabel(today), '09:05');
      expect(
        timestampLabel(sameYear),
        sameYear.month == 12 ? 'Dec 15' : 'Jan 15',
      );
      expect(timestampLabel(previousYear), 'Nov 4, ${now.year - 1}');
    });
  });

  group('conversation date filters', () {
    test('filters conversations by today week month and custom ranges', () {
      final now = DateTime(2026, 6, 18, 15);
      final conversations = [
        _conversation('today', DateTime(2026, 6, 18, 9)),
        _conversation('this-week', DateTime(2026, 6, 16, 9)),
        _conversation('this-month', DateTime(2026, 6, 1, 9)),
        _conversation('older', DateTime(2026, 5, 31, 9)),
        _conversation('undated', null),
      ];

      expect(
        filterConversationsByDate(
          conversations,
          const ConversationDateFilter.today(),
          now: now,
        ).map((conversation) => conversation.id),
        ['today'],
      );
      expect(
        filterConversationsByDate(
          conversations,
          const ConversationDateFilter.thisWeek(),
          now: now,
        ).map((conversation) => conversation.id),
        ['today', 'this-week'],
      );
      expect(
        filterConversationsByDate(
          conversations,
          const ConversationDateFilter.thisMonth(),
          now: now,
        ).map((conversation) => conversation.id),
        ['today', 'this-week', 'this-month'],
      );
      expect(
        filterConversationsByDate(
          conversations,
          ConversationDateFilter.custom(
            start: DateTime(2026, 5, 31),
            end: DateTime(2026, 6, 1),
          ),
          now: now,
        ).map((conversation) => conversation.id),
        ['this-month', 'older'],
      );
    });

    test('filters search results with the same date rules', () {
      final now = DateTime(2026, 6, 18, 15);
      final results = [
        _searchResult('today', DateTime(2026, 6, 18, 9)),
        _searchResult('this-week', DateTime(2026, 6, 16, 9)),
        _searchResult('older', DateTime(2026, 5, 31, 9)),
      ];

      expect(
        filterConversationSearchResultsByDate(
          results,
          const ConversationDateFilter.thisWeek(),
          now: now,
        ).map((result) => result.conversationId),
        ['today', 'this-week'],
      );
    });
  });
}

Conversation _conversation(String id, DateTime? timestamp) {
  return Conversation(id: id, timestamp: timestamp);
}

ConversationSearchResult _searchResult(String id, DateTime timestamp) {
  return ConversationSearchResult(
    conversationId: id,
    matchType: 'message',
    preview: id,
    conversationTimestamp: timestamp,
  );
}
