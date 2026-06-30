import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/memory/data/memory_api.dart';
import 'package:clarity/rex/memory/data/memory_constants.dart';
import 'package:clarity/rex/memory/application/memory_controller.dart';
import 'package:clarity/rex/memory/data/entity_memory_model.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/data/memory_paged_result.dart';
import 'package:clarity/rex/memory/presentation/memory_l10n.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_page_filters.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_quick_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_page_test_helpers.dart';

void main() {
  group('entity memory alignment', () {
    test('EntityMemoryItem maps entity types to Knows groups', () {
      final place = EntityMemoryItem.fromJson({
        'id': 'place-1',
        'entity_type': 'place',
        'display_name': 'Somerville',
        'importance': 4,
        'active': true,
      });
      final organization = EntityMemoryItem.fromJson({
        'id': 'org-1',
        'entity_type': 'organization',
        'display_name': 'Bom Dough',
        'importance': 3,
        'active': true,
      });

      expect(place.memoryGroup, MemoryGroup.places);
      expect(organization.memoryGroup, MemoryGroup.other);
    });

    test('PersonMemoryItem can be built from a person entity', () {
      final entity = EntityMemoryItem.fromJson({
        'id': 'person-1',
        'entity_type': 'person',
        'display_name': 'Pedro Martins',
        'relationship': 'self',
        'summary': 'Builder at Clarity.',
        'aliases': ['Pedro'],
        'importance': 5,
        'status': 'active',
        'active': true,
        'metadata': const {},
      });

      final person = PersonMemoryItem.fromEntity(entity);

      expect(person.displayName, 'Pedro Martins');
      expect(person.relationship, 'self');
    });

    test('filterSavedMemory surfaces place entities in Places group', () {
      const state = MemoryState(
        placeEntities: [
          EntityMemoryItem(
            id: 'place-1',
            entityType: 'place',
            displayName: 'Somerville',
            relationship: null,
            summary: 'Home city.',
            aliases: [],
            importance: 4,
            status: 'active',
            active: true,
            metadata: {},
          ),
        ],
      );

      final filtered = filterSavedMemory(
        state: state,
        query: '',
        quickFilter: MemoryQuickFilter.saved,
      );

      expect(filtered.placeEntities, hasLength(1));
      expect(filtered.placeEntities.first.displayName, 'Somerville');
    });

    test('filterSavedMemory hides flat place memory covered by place entity', () {
      const linkedMemory = MemoryItem(
        id: 'memory-place-flat',
        memoryType: MemoryType.fact,
        content: 'User lives in Somerville.',
        importance: 4,
        active: true,
        metadata: {'memory_category': 'Places'},
      );
      const placeEntity = EntityMemoryItem(
        id: 'place-1',
        entityType: 'place',
        displayName: 'Somerville',
        relationship: null,
        summary: 'Home city.',
        aliases: [],
        importance: 4,
        status: 'active',
        active: true,
        metadata: {'source_memory_ids': ['memory-place-flat']},
      );

      final filtered = filterSavedMemory(
        state: const MemoryState(
          memories: [linkedMemory],
          placeEntities: [placeEntity],
        ),
        query: '',
        quickFilter: MemoryQuickFilter.saved,
      );

      expect(filtered.places, isEmpty);
      expect(filtered.placeEntities, hasLength(1));
    });

    test('memory group labels localize in Spanish', () {
      final es = lookupAppLocalizations(const Locale('es'));

      expect(MemoryGroup.places.localizedLabel(es), 'Lugares');
      expect(MemoryGroup.people.localizedLabel(es), 'Personas');
      expect(entityTypeLabel(es, 'place'), 'Lugar');
      expect(localizedMemoryRecordLabel(es, 'gentle_direct'), 'Recordatorio amable');
    });

    test('overviewCanLoadMore reflects cursor pagination state', () {
      const firstPage = MemoryState(
        overviewPages: MemoryOverviewPages(memoriesHasMore: true),
      );
      const lastPage = MemoryState(
        overviewPages: MemoryOverviewPages(),
      );

      expect(firstPage.overviewCanLoadMore, isTrue);
      expect(lastPage.overviewCanLoadMore, isFalse);
    });

    test('loadSavedOverview loads plan milestone previews', () async {
      final api = MemoryPageFakeMemoryApi();
      final container = ProviderContainer(
        overrides: [memoryApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      await container.read(memoryProvider.notifier).loadSavedOverview();
      final state = container.read(memoryProvider);

      expect(state.milestonePreviewsFor('plan-1'), isNotEmpty);
    });
  });
}
