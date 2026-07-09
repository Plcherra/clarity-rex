import 'package:clarity/rex/chat/domain/chat_message.dart';

List<ClarityActionCard> clarityActionCardsFromMemoryChanges(
  Map<String, dynamic>? memoryChanges, {
  bool allowConfirmCards = true,
}) {
  if (memoryChanges == null || !allowConfirmCards) {
    return const [];
  }
  final cards = <ClarityActionCard>[];
  final seenIds = <String>{};
  for (final key in [
    'write_proposals',
    'clarity_action_proposals',
    'plan_save_proposals',
  ]) {
    final proposals = memoryChanges[key];
    if (proposals is! List) {
      continue;
    }
    for (final proposal in proposals) {
      if (proposal is! Map<String, dynamic>) {
        continue;
      }
      final card = ClarityActionCard.fromJson(proposal);
      // Text-only mode: never surface pending confirm cards.
      if (card.isPending && memoryChanges['text_confirmation_pending'] == true) {
        continue;
      }
      if (card.id.isEmpty || seenIds.add(card.id)) {
        cards.add(card);
      }
    }
  }
  return List.unmodifiable(cards);
}
