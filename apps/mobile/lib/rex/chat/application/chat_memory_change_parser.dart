import 'package:clarity/rex/chat/domain/chat_message.dart';

List<ClarityActionCard> clarityActionCardsFromMemoryChanges(
  Map<String, dynamic>? memoryChanges,
) {
  if (memoryChanges == null) {
    return const [];
  }
  final proposals = memoryChanges['clarity_action_proposals'];
  if (proposals is! List) {
    return const [];
  }

  final cards = <ClarityActionCard>[];
  for (final proposal in proposals) {
    if (proposal is Map<String, dynamic>) {
      cards.add(ClarityActionCard.fromJson(proposal));
    }
  }
  return List.unmodifiable(cards);
}
