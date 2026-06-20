import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('memory-facing labels', () {
    test('maps memory action types to human labels', () {
      expect(memoryActionTypeLabel('long_term_memory'), 'Memory note');
      expect(memoryActionTypeLabel('entity'), 'Person / place');
      expect(memoryActionTypeLabel('entity_event'), 'Related event');
      expect(memoryActionTypeLabel('correction'), 'Correction');
      expect(memoryActionTypeLabel('plan_milestone'), 'Milestone');
    });

    test('maps risk and action status labels to readable copy', () {
      expect(memoryRiskLevelLabel('low'), 'Low risk');
      expect(memoryRiskLevelLabel('medium'), 'Medium risk');
      expect(memoryRiskLevelLabel('high'), 'High risk');
      expect(memoryActionStatusLabel('applied'), 'Saved');
      expect(memoryActionStatusLabel('failed'), 'Needs attention');
    });

    test('uses readable fallback for unknown backend values', () {
      expect(memoryActionTypeLabel('custom_memory_kind'), 'Custom Memory Kind');
      expect(memoryRiskLevelLabel('needs_review'), 'Needs Review');
      expect(memoryActionStatusLabel('waitingForUser'), 'Waiting For User');
      expect(memoryGroupForTypeLabel('custom_memory_kind'), MemoryGroup.other);
      expect(memoryGroupForTypeLabel('custom_memory_kind').label, 'Other');
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

    test('saved memory category metadata controls Knows grouping', () {
      final place = MemoryItem.fromJson({
        'id': 'memory-place',
        'memory_type': 'fact',
        'content': 'Pedro lives in Somerville.',
        'importance': 4,
        'active': true,
        'metadata': {'memory_category': 'Places'},
      });
      final goal = MemoryItem.fromJson({
        'id': 'memory-goal',
        'memory_type': 'event',
        'content': 'Pedro plans to call mom.',
        'importance': 3,
        'active': true,
        'metadata': {'memory_category': 'Goals'},
      });

      expect(place.memoryGroup, MemoryGroup.places);
      expect(place.categoryLabel, 'Places');
      expect(goal.memoryGroup, MemoryGroup.goals);
      expect(goal.categoryLabel, 'Goals');
    });

    test('saved memory category metadata supports Other grouping', () {
      final other = MemoryItem.fromJson({
        'id': 'memory-other',
        'memory_type': 'fact',
        'content': 'Pedro saved a custom detail.',
        'importance': 2,
        'active': true,
        'metadata': {'memory_category': 'Other'},
      });

      expect(other.memoryGroup, MemoryGroup.other);
      expect(other.categoryLabel, 'Other');
    });

    test('cleans raw type prefixes from memory preview text', () {
      expect(
        memoryPreviewWithRecordType('long_term_memory: Pedro prefers email'),
        'Memory note: Pedro prefers email',
      );
      expect(
        memoryPreviewWithRecordType('entity_event: Lunch with Ana'),
        'Related event: Lunch with Ana',
      );
    });

    test('accountability source labels avoid raw enum names', () {
      const source = AccountabilitySourceRef(
        sourceType: AccountabilitySourceType.longTermMemory,
        sourceId: 'memory-1',
        title: null,
        excerpt: null,
        metadata: {},
      );

      expect(source.displayLabel, 'Memory');
    });
  });
}
