import 'package:clarity/features/assistant/accountability/data/accountability_models.dart';
import 'package:clarity/features/assistant/chat/domain/chat_message.dart';
import 'package:clarity/features/assistant/memory/data/memory_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('memory-facing labels', () {
    test('maps memory candidate types to human labels', () {
      expect(memoryCandidateTypeLabel('long_term_memory'), 'Memory note');
      expect(memoryCandidateTypeLabel('entity'), 'Person / place');
      expect(memoryCandidateTypeLabel('entity_event'), 'Related event');
      expect(memoryCandidateTypeLabel('correction'), 'Correction');
      expect(memoryCandidateTypeLabel('plan_milestone'), 'Milestone');
    });

    test('maps risk and status labels to review copy', () {
      expect(memoryRiskLevelLabel('low'), 'Low risk');
      expect(memoryRiskLevelLabel('medium'), 'Medium risk');
      expect(memoryRiskLevelLabel('high'), 'High risk');
      expect(memoryCandidateStatusLabel('pending'), 'Needs review');
      expect(memoryCandidateStatusLabel('applied'), 'Saved');
      expect(memoryCandidateStatusLabel('failed'), 'Needs attention');
    });

    test('uses readable fallback for unknown backend values', () {
      expect(
        memoryCandidateTypeLabel('custom_memory_kind'),
        'Custom Memory Kind',
      );
      expect(memoryRiskLevelLabel('needs_review'), 'Needs Review');
      expect(memoryCandidateStatusLabel('waitingForUser'), 'Waiting For User');
      expect(memoryGroupForTypeLabel('custom_memory_kind'), MemoryGroup.other);
      expect(
        memoryGroupForTypeLabel('custom_memory_kind').label,
        'Other memories',
      );
    });

    test('unknown durable memory types render as other memories', () {
      final memory = MemoryItem.fromJson({
        'id': 'memory-custom',
        'memory_type': 'custom_memory_kind',
        'content': 'Pedro likes careful release gates.',
        'importance': 3,
        'active': true,
      });

      expect(memory.memoryType, MemoryType.other);
      expect(memory.memoryType.memoryGroup, MemoryGroup.other);
      expect(memory.memoryType.label, 'Other memory');
    });

    test('cleans raw type prefixes from candidate preview text', () {
      expect(
        memoryPreviewWithHumanType('long_term_memory: Pedro prefers email'),
        'Memory note: Pedro prefers email',
      );
      expect(
        memoryPreviewWithHumanType('entity_event: Lunch with Ana'),
        'Related event: Lunch with Ana',
      );
    });

    test('chat memory candidate exposes display labels', () {
      final candidate = MemoryCandidateCard.fromJson({
        'id': 'candidate-1',
        'candidate_type': 'long_term_memory',
        'status': 'pending',
        'risk_level': 'high',
        'preview': 'long_term_memory: Pedro prefers email',
        'review_reason': 'Extracted memory needs review before saving.',
        'reason': 'Raw extractor rationale.',
      });

      expect(candidate.candidateTypeLabel, 'Memory note');
      expect(candidate.statusLabel, 'Needs review');
      expect(candidate.riskLabel, 'High risk');
      expect(candidate.previewLabel, 'Memory note: Pedro prefers email');
      expect(candidate.reviewTitleLabel, 'Proposed memory');
      expect(candidate.expectedActionLabel, 'Save this only after approval');
      expect(
        candidate.reasonLabel,
        'Extracted memory needs review before saving.',
      );
    });

    test('memory review candidate prefers review reason copy', () {
      final candidate = PendingMemoryCandidateItem.fromJson({
        'id': 'candidate-1',
        'candidate_type': 'long_term_memory',
        'status': 'pending',
        'risk_level': 'medium',
        'preview': 'long_term_memory: Pedro prefers email',
        'review_reason': 'Review this before Rex saves it.',
        'reason': 'Raw extractor rationale.',
      });

      expect(candidate.reasonLabel, 'Review this before Rex saves it.');
    });

    test('accountability source and candidate labels avoid raw enum names', () {
      const source = AccountabilitySourceRef(
        sourceType: AccountabilitySourceType.longTermMemory,
        sourceId: 'memory-1',
        title: null,
        excerpt: null,
        metadata: {},
      );
      final candidate = PendingMemoryCandidate.fromJson({
        'id': 'candidate-2',
        'candidate_type': 'entity_event',
        'status': 'failed',
        'risk_level': 'medium',
        'preview': 'entity_event: Met Sofia',
      });

      expect(source.displayLabel, 'Memory');
      expect(candidate.candidateTypeLabel, 'Related event');
      expect(candidate.statusLabel, 'Needs attention');
      expect(candidate.riskLabel, 'Medium risk');
      expect(candidate.previewLabel, 'Related event: Met Sofia');
    });
  });
}
