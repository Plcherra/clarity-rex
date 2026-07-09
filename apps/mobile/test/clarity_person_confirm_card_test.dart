import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/rex/chat/domain/chat_message.dart';

void main() {
  group('ClarityPersonCardData', () {
    test('parses person_card from proposal json', () {
      final action = ClarityActionCard.fromJson({
        'id': 'write-1',
        'action': 'save_memory',
        'write_kind': 'memory',
        'confirmation_text': 'Save person?',
        'risk_level': 'medium',
        'status': 'pending',
        'editable_fields': [
          'display_name',
          'relationship',
          'birthday',
          'notes',
        ],
        'title': "User's mother is Ariadyna",
        'body': "User's mother is Ariadyna.",
        'person_card': {
          'display_name': 'Ariadyna',
          'relationship': 'mother',
          'birthday': 'June 18',
          'notes': '',
          'merge_hint': 'We already have related info about your mother.',
          'related_summary': 'birthday June 18',
        },
      });

      expect(action.personCard, isNotNull);
      expect(action.personCard!.displayName, 'Ariadyna');
      expect(action.personCard!.relationship, 'mother');
      expect(action.personCard!.birthday, 'June 18');
      expect(action.personCard!.mergeHint, contains('related info'));
      expect(action.personCard!.toEdits()['display_name'], 'Ariadyna');
      expect(action.personCard!.toEdits()['relationship'], 'mother');
    });

    test('filled field count gate matches two-field rule', () {
      const oneField = ClarityPersonCardData(relationship: 'mother');
      const twoFields = ClarityPersonCardData(
        displayName: 'Ariadyna',
        relationship: 'mother',
      );
      int filled(ClarityPersonCardData card) {
        return [
          card.displayName,
          card.relationship,
          card.birthday,
          card.notes,
        ].where((value) => value.trim().isNotEmpty).length;
      }

      expect(filled(oneField), 1);
      expect(filled(twoFields), 2);
      expect(filled(oneField) >= 2, isFalse);
      expect(filled(twoFields) >= 2, isTrue);
    });
  });
}
