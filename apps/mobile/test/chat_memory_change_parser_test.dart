import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/rex/chat/application/chat_memory_change_parser.dart';

void main() {
  test('reads text confirmation pending proposal id', () {
    expect(
      textConfirmationPendingProposalIdFromMemoryChanges({
        'text_confirmation_pending': true,
        'pending_proposal_id': 'write-text-1',
        'write_proposals': <dynamic>[],
      }),
      'write-text-1',
    );
    expect(
      textConfirmationPendingProposalIdFromMemoryChanges({
        'confirmation_required': 1,
        'write_proposals': <dynamic>[],
      }),
      isNull,
    );
  });

  test('typed affirmations match backend say-yes phrases', () {
    expect(isTypedAffirmationMessage('yes'), isTrue);
    expect(isTypedAffirmationMessage('save it'), isTrue);
    expect(isTypedAffirmationMessage('confirm'), isTrue);
    // Casual chat must not apply a pending write.
    expect(isTypedAffirmationMessage('Sure'), isFalse);
    expect(isTypedAffirmationMessage('ok'), isFalse);
    expect(isTypedAffirmationMessage('sounds good'), isFalse);
    expect(isTypedAffirmationMessage('yesterday'), isFalse);
    expect(isTypedAffirmationMessage('yes update it'), isFalse);
  });

  test('hides pending cards when text_confirmation_pending is set', () {
    final cards = clarityActionCardsFromMemoryChanges({
      'confirmation_required': 1,
      'text_confirmation_pending': true,
      'write_proposals': [
        {
          'id': 'write-1',
          'action': 'save_memory',
          'write_kind': 'memory',
          'confirmation_text': 'Save?',
          'risk_level': 'medium',
          'status': 'pending',
          'title': 'Mom',
          'body': 'Birthday',
        },
      ],
    });
    expect(cards, isEmpty);
  });

  test('allowConfirmCards false suppresses all cards', () {
    final cards = clarityActionCardsFromMemoryChanges(
      {
        'write_proposals': [
          {
            'id': 'write-1',
            'action': 'save_memory',
            'write_kind': 'memory',
            'confirmation_text': 'Save?',
            'risk_level': 'medium',
            'status': 'pending',
          },
        ],
      },
      allowConfirmCards: false,
    );
    expect(cards, isEmpty);
  });

  test('still shows applied status cards', () {
    final cards = clarityActionCardsFromMemoryChanges({
      'confirmation_required': 0,
      'write_proposals': [
        {
          'id': 'write-1',
          'action': 'save_memory',
          'write_kind': 'memory',
          'confirmation_text': 'Saved',
          'risk_level': 'medium',
          'status': 'applied',
          'result': [
            {'id': 'mem-1', 'action': 'direct_saved'},
          ],
        },
      ],
    });
    expect(cards, hasLength(1));
    expect(cards.first.isApplied, isTrue);
  });
}
