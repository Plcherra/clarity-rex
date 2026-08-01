import 'package:clarity/rex/memory/application/memory_controller.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_page_filters.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_quick_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterSavedMemory person dedup', () {
    test('hides flat memory covered by active person sourceMemoryIds', () {
      const linkedMemory = MemoryItem(
        id: 'memory-cousin-birthday',
        memoryType: MemoryType.fact,
        content: "Cousin Ana's birthday is July 9.",
        importance: 5,
        active: true,
        metadata: {'memory_category': 'People'},
      );
      const person = PersonMemoryItem(
        id: 'person-ana',
        displayName: 'Cousin Ana',
        relationship: 'cousin',
        summary: 'Birthday: July 9.',
        aliases: [],
        importance: 5,
        status: 'active',
        active: true,
        metadata: {'source_memory_ids': ['memory-cousin-birthday']},
      );

      final results = filterSavedMemory(
        state: const MemoryState(memories: [linkedMemory], people: [person]),
        query: '',
        quickFilter: MemoryQuickFilter.saved,
      );

      expect(results.peopleMemories, isEmpty);
      expect(results.people, hasLength(1));
    });

    test('hides flat memory linked by canonical_entity_id when person archived', () {
      const linkedMemory = MemoryItem(
        id: 'memory-cousin-birthday',
        memoryType: MemoryType.fact,
        content: "Cousin Ana's birthday is July 9.",
        importance: 5,
        active: true,
        metadata: {
          'memory_category': 'People',
          'canonical_entity_id': 'person-ana',
        },
      );

      final results = filterSavedMemory(
        state: const MemoryState(memories: [linkedMemory], people: []),
        query: '',
        quickFilter: MemoryQuickFilter.saved,
      );

      expect(results.peopleMemories, isEmpty);
    });

    test('does not hide unrelated flat memories when person archived', () {
      const unrelatedMemory = MemoryItem(
        id: 'memory-other',
        memoryType: MemoryType.fact,
        content: 'User likes hiking.',
        importance: 3,
        active: true,
        metadata: {'memory_category': 'Preferences'},
      );

      final results = filterSavedMemory(
        state: const MemoryState(memories: [unrelatedMemory], people: []),
        query: '',
        quickFilter: MemoryQuickFilter.saved,
      );

      expect(results.preferences, hasLength(1));
    });
  });
}
