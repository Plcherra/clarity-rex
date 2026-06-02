import 'package:clarity/features/assistant/chat/domain/chat_message.dart';

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

List<MemoryCandidateCard> candidateCardsFromMemoryChanges(
  Map<String, dynamic>? memoryChanges,
) {
  if (memoryChanges == null) {
    return const [];
  }

  final cards = <MemoryCandidateCard>[];
  for (final key in const [
    'pending_candidates',
    'applied_candidates',
    'failed_candidates',
    'skipped_candidates',
    'rejected_candidates',
  ]) {
    final value = memoryChanges[key];
    if (value is! List) {
      continue;
    }
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        cards.add(MemoryCandidateCard.fromJson(item));
      }
    }
  }
  if (cards.isNotEmpty) {
    return List.unmodifiable(cards);
  }

  final records = memoryChanges['records'];
  if (records is! List) {
    return const [];
  }
  for (final record in records) {
    if (record is! Map<String, dynamic>) {
      continue;
    }
    final candidate = record['candidate'];
    if (candidate is Map<String, dynamic>) {
      cards.add(MemoryCandidateCard.fromJson(candidate));
    }
  }
  return List.unmodifiable(cards);
}
