import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/rex/chat/data/chat_models.dart';
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
}

Conversation _conversation(String id, DateTime? timestamp) {
  return Conversation(id: id, timestamp: timestamp);
}
