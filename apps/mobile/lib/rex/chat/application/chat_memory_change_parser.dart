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

/// Proposal id for Text / Off+explicit say-yes (no card).
String? textConfirmationPendingProposalIdFromMemoryChanges(
  Map<String, dynamic>? memoryChanges,
) {
  if (memoryChanges == null) {
    return null;
  }
  if (memoryChanges['text_confirmation_pending'] != true) {
    return null;
  }
  final id = memoryChanges['pending_proposal_id']?.toString().trim() ?? '';
  return id.isEmpty ? null : id;
}

/// Whether memory_changes indicate the pending text confirm was resolved.
bool memoryChangesClearTextConfirmationPending(
  Map<String, dynamic>? memoryChanges,
) {
  if (memoryChanges == null) {
    return false;
  }
  if (memoryChanges['text_confirmation_pending'] == true) {
    return false;
  }
  final required = memoryChanges['confirmation_required'];
  if (required is num && required == 0) {
    return true;
  }
  final proposals = memoryChanges['write_proposals'];
  if (proposals is List) {
    for (final proposal in proposals) {
      if (proposal is Map &&
          (proposal['status'] == 'applied' ||
              proposal['status'] == 'dismissed' ||
              proposal['status'] == 'failed')) {
        return true;
      }
    }
  }
  return false;
}

/// Short whole-message affirmations aligned with backend
/// [is_affirmative_confirmation].
/// Narrow on purpose — casual chat ("ok", "sure") must not apply pending writes.
bool isTypedAffirmationMessage(String message) {
  final normalized = message
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9']+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  const affirmations = {
    'yes',
    'yes please',
    'please do',
    'do it',
    'confirm',
    'confirmed',
    'save it',
    'save that',
    'save this',
  };
  return affirmations.contains(normalized);
}
