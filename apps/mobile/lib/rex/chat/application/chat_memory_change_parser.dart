import 'package:clarity/rex/chat/domain/chat_message.dart';

List<ClarityActionCard> clarityActionCardsFromMemoryChanges(
  Map<String, dynamic>? memoryChanges,
) {
  if (memoryChanges == null) {
    return const [];
  }
  final cards = <ClarityActionCard>[];
  for (final key in ['clarity_action_proposals', 'plan_save_proposals']) {
    final proposals = memoryChanges[key];
    if (proposals is! List) {
      continue;
    }
    for (final proposal in proposals) {
      if (proposal is Map<String, dynamic>) {
        cards.add(ClarityActionCard.fromJson(proposal));
      }
    }
  }
  return List.unmodifiable(cards);
}
