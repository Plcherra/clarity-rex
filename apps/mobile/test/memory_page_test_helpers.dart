import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:clarity/rex/memory/data/memory_constants.dart';
import 'package:clarity/rex/memory/data/memory_paged_result.dart';
import 'package:clarity/rex/memory/data/memory_api.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/pages/memory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/l10n_test_wrapper.dart';

Future<void> pumpMemoryPage(
  WidgetTester tester,
  MemoryPageFakeMemoryApi api,
) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData({});
  final localeController = LocaleController(
    preferences: SharedPreferencesAsync(),
  );
  await localeController.load();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        memoryApiProvider.overrideWithValue(api),
        localeControllerProvider.overrideWithValue(localeController),
      ],
      child: wrapWithL10n(const MemoryPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder listTileText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == text,
    description: 'visible memory text "$text"',
  );
}

Future<void> openFirstMemoryActions(WidgetTester tester) async {
  await openMemoryActionsForText(tester, 'Pedro is building Clarity.');
}

Future<void> openMemoryActionsForText(WidgetTester tester, String text) async {
  final label = listTileText(text);
  await tester.scrollUntilVisible(
    label,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(label);
  await tester.pumpAndSettle();
  final tile = find.ancestor(of: label, matching: find.byType(GestureDetector));
  await tester.tap(
    find.descendant(of: tile.first, matching: find.byTooltip('Memory actions')),
  );
  await tester.pumpAndSettle();
}

class MemoryPageFakeMemoryApi extends MemoryApi {
  MemoryPageFakeMemoryApi({this.loadError, this.archiveError, this.truncateLists = false});

  final Object? loadError;
  final Object? archiveError;
  final bool truncateLists;
  final archivedMemoryIds = <String>[];
  String? updatedMemoryId;
  String? updatedContent;
  MemoryType? updatedMemoryType;
  final memoryActiveFilters = <bool?>[];
  final entityActiveFilters = <bool?>[];
  final peopleActiveFilters = <bool?>[];
  final ruleActiveFilters = <bool?>[];
  final planActiveFilters = <bool?>[];
  final memoryListLimits = <int>[];
  String? createMemoryContent;
  String? createPersonNameValue;

  @override
  Future<MemoryItem> createMemory({
    required MemoryType memoryType,
    required String content,
    int importance = 3,
    String? memoryCategory,
  }) async {
    createMemoryContent = content;
    return MemoryItem(
      id: 'memory-created',
      memoryType: memoryType,
      content: content,
      importance: importance,
      active: true,
      metadata: {
        if (memoryCategory != null) 'memory_category': memoryCategory,
      },
      createdAt: DateTime.utc(2026, 6, 1),
      updatedAt: DateTime.utc(2026, 6, 1),
    );
  }

  @override
  Future<PersonMemoryItem> createPerson({
    required String displayName,
    String? relationship,
    String? summary,
    int importance = 3,
  }) async {
    createPersonNameValue = displayName;
    return PersonMemoryItem(
      id: 'person-created',
      displayName: displayName,
      relationship: relationship,
      summary: summary,
      aliases: const [],
      importance: importance,
      status: 'active',
      active: true,
      metadata: const {},
      createdAt: DateTime.utc(2026, 6, 1),
      updatedAt: DateTime.utc(2026, 6, 1),
    );
  }

  @override
  Future<List<MemoryItem>> getMemories({
    MemoryType? memoryType,
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    if (loadError != null) {
      throw loadError!;
    }
    memoryActiveFilters.add(active);
    memoryListLimits.add(limit);
    if (truncateLists) {
      return _manyMemories(startIndex: 0, count: limit);
    }
    final memories = [
      MemoryItem(
        id: 'memory-0',
        memoryType: MemoryType.fact,
        content: 'My name is Pedro Martins.',
        importance: 5,
        active: true,
        metadata: const {'memory_category': 'People'},
        createdAt: DateTime.utc(2026, 5, 31, 12),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
      MemoryItem(
        id: 'memory-1',
        memoryType: MemoryType.preference,
        content: 'Pedro prefers email updates.',
        importance: 3,
        active: true,
        createdAt: DateTime.utc(2026, 5, 31, 12),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
      MemoryItem(
        id: 'memory-2',
        memoryType: MemoryType.fact,
        content: 'Pedro is building Clarity.',
        importance: 4,
        active: true,
        createdAt: DateTime.utc(2026, 5, 30),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
      MemoryItem(
        id: 'memory-3',
        memoryType: MemoryType.event,
        content: 'MFA was enabled successfully.',
        importance: 2,
        active: true,
        createdAt: DateTime.utc(2026, 5, 30),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
      MemoryItem(
        id: 'memory-4',
        memoryType: MemoryType.fact,
        content: 'User lives in Somerville.',
        importance: 5,
        active: true,
        metadata: const {'memory_category': 'Places'},
        createdAt: DateTime.utc(2026, 5, 31, 12),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
      MemoryItem(
        id: 'memory-inactive',
        memoryType: MemoryType.fact,
        content: 'Inactive flat fallback memory.',
        importance: 2,
        active: false,
        createdAt: DateTime.utc(2026, 5, 31, 12),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
    ];
    return _filterMemories(memories, memoryType: memoryType, active: active);
  }

  List<MemoryItem> _manyMemories({required int startIndex, required int count}) {
    return List<MemoryItem>.generate(count, (index) {
      final absoluteIndex = startIndex + index;
      return MemoryItem(
        id: 'memory-bulk-$absoluteIndex',
        memoryType: MemoryType.fact,
        content: 'Bulk memory item $absoluteIndex.',
        importance: 2,
        active: true,
        createdAt: DateTime.utc(2026, 5, 31, 12),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      );
    }, growable: false);
  }

  @override
  Future<List<EntityMemoryItem>> getEntities({
    String? entityType,
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    entityActiveFilters.add(active);
    final entities = [
      EntityMemoryItem(
        id: 'person-1',
        entityType: 'person',
        displayName: 'Pedro Martins',
        relationship: 'self',
        summary:
            'Full name: Pedro Martins. Lives in Somerville. Birthday: June 18. Works at Bom Dough.',
        aliases: const ['Bank of America', 'Bom Dough payroll'],
        importance: 5,
        status: 'active',
        active: true,
        metadata: const {
          'attributes': {
            'full_name': 'Pedro Martins',
            'location': 'Somerville',
            'birthday': 'June 18',
            'workplace': 'Bom Dough',
            'notes': 'Works at Bom Dough',
            'important_dates': ['Launch review: 2026-06-20'],
          },
          'source_memory_ids': ['memory-0', 'memory-4'],
        },
        createdAt: DateTime.utc(2026, 5, 30),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
      EntityMemoryItem(
        id: 'person-inactive',
        entityType: 'person',
        displayName: 'Inactive Person',
        relationship: 'former context',
        summary: 'Archived person record.',
        aliases: const [],
        importance: 2,
        status: 'inactive',
        active: false,
        metadata: const {},
        createdAt: DateTime.utc(2026, 5, 30),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
      EntityMemoryItem(
        id: 'place-1',
        entityType: 'place',
        displayName: 'Somerville',
        relationship: null,
        summary: 'Home city.',
        aliases: const [],
        importance: 4,
        status: 'active',
        active: true,
        metadata: const {
          'attributes': {'location': 'Somerville'},
        },
        createdAt: DateTime.utc(2026, 5, 30),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
    ];
    return entities
        .where((entity) {
          if (entityType != null && entity.entityType != entityType) {
            return false;
          }
          if (active != null && entity.active != active) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  @override
  Future<List<PersonMemoryItem>> getPeople({
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    peopleActiveFilters.add(active);
    final entities = await getEntities(entityType: 'person', active: active);
    return entities.map(PersonMemoryItem.fromEntity).toList(growable: false);
  }

  @override
  Future<List<EntityEventItem>> getEntityEvents(
    String entityId, {
    bool? active,
    int limit = kEntityEventPreviewLimit,
  }) async {
    if (entityId == 'place-1') {
      return [
        EntityEventItem(
          id: 'event-1',
          entityId: entityId,
          eventType: 'note',
          title: 'Moved to Somerville',
          content: 'Moved to Somerville in 2024.',
          importance: 3,
          active: true,
        ),
      ];
    }
    return const [];
  }

  @override
  Future<MemoryPagedResult<MemoryItem>> getMemoriesPaged({
    MemoryType? memoryType,
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    memoryListLimits.add(limit);
    if (truncateLists) {
      if (cursor != null) {
        return MemoryPagedResult(
          items: _manyMemories(
            startIndex: kMemoryListLimit,
            count: kMemoryLoadMoreStep,
          ),
        );
      }
      return MemoryPagedResult(
        items: _manyMemories(startIndex: 0, count: kMemoryListLimit),
        hasMore: true,
        nextCursor: 'offset-50',
      );
    }
    final items = await getMemories(
      memoryType: memoryType,
      active: active,
      limit: limit,
    );
    return MemoryPagedResult(items: items);
  }

  @override
  Future<MemoryPagedResult<EntityMemoryItem>> getEntitiesPaged({
    String? entityType,
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    final items = await getEntities(
      entityType: entityType,
      active: active,
      limit: limit,
    );
    return MemoryPagedResult(items: items);
  }

  @override
  Future<MemoryPagedResult<RuleMemoryItem>> getRulesPaged({
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    final items = await getRules(active: active, limit: limit);
    return MemoryPagedResult(items: items);
  }

  @override
  Future<MemoryPagedResult<PlanMemoryItem>> getPlansPaged({
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    final items = await getPlans(active: active, limit: limit);
    return MemoryPagedResult(items: items);
  }

  @override
  Future<List<PlanMilestoneMemoryItem>> getPlanMilestones(
    String planId, {
    bool? active,
    int limit = kPlanMilestonePreviewLimit,
  }) async {
    if (planId == 'plan-1') {
      return [
        PlanMilestoneMemoryItem(
          id: 'milestone-1',
          planId: planId,
          title: 'Submit compliance docs',
          description: 'Gather policy and security material.',
          milestoneType: 'checkpoint',
          priority: 4,
          status: 'open',
          active: true,
        ),
      ];
    }
    return const [];
  }

  @override
  Future<List<RuleMemoryItem>> getRules({bool? active, int limit = kMemoryListLimit}) async {
    ruleActiveFilters.add(active);
    final rules = [
      RuleMemoryItem(
        id: 'rule-1',
        ruleType: 'gentle_direct',
        title: 'Be concise',
        ruleText: 'Keep advice direct unless Pedro asks for depth.',
        triggerKeywords: const ['communication'],
        priority: 3,
        status: 'active',
        active: true,
        createdAt: DateTime.utc(2026, 5, 30),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
    ];
    return _filterActive(rules, active, (rule) => rule.active);
  }

  @override
  Future<List<PlanMemoryItem>> getPlans({bool? active, int limit = kMemoryListLimit}) async {
    planActiveFilters.add(active);
    final plans = [
      PlanMemoryItem(
        id: 'plan-1',
        planType: 'project',
        title: 'Ship Plaid review',
        description: 'Prepare policy and security material.',
        desiredOutcome: 'Compliance-ready submission',
        priority: 4,
        status: 'active',
        active: true,
        targetDate: DateTime.utc(2026, 6),
        primaryEntityId: null,
        createdAt: DateTime.utc(2026, 5, 30),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
    ];
    return _filterActive(plans, active, (plan) => plan.active);
  }

  @override
  Future<MemoryItem> updateMemory(
    String memoryId, {
    MemoryType? memoryType,
    String? content,
    int? importance,
    bool? active,
  }) async {
    updatedMemoryId = memoryId;
    updatedContent = content;
    updatedMemoryType = memoryType;
    return MemoryItem(
      id: memoryId,
      memoryType: memoryType ?? MemoryType.preference,
      content: content ?? 'Pedro prefers email updates.',
      importance: importance ?? 3,
      active: active ?? true,
      createdAt: DateTime.utc(2026, 5, 31, 12),
      updatedAt: DateTime.utc(2026, 5, 31, 12),
    );
  }

  @override
  Future<void> archiveMemory(String memoryId) async {
    if (archiveError != null) {
      throw archiveError!;
    }
    archivedMemoryIds.add(memoryId);
  }

  @override
  Future<void> deactivateMemory(String memoryId) async {
    await archiveMemory(memoryId);
  }

  final milestoneCreates = <Map<String, String>>[];
  final milestoneUpdates = <String>[];

  @override
  Future<PlanMilestoneMemoryItem> createPlanMilestone(
    String planId, {
    required String title,
    String? description,
    String milestoneType = 'checkpoint',
    int priority = 3,
  }) async {
    milestoneCreates.add({
      'planId': planId,
      'title': title,
      if (description != null) 'description': description,
    });
    return PlanMilestoneMemoryItem(
      id: 'milestone-new',
      planId: planId,
      title: title,
      description: description,
      milestoneType: milestoneType,
      priority: priority,
      status: 'open',
      active: true,
    );
  }

  @override
  Future<PlanMilestoneMemoryItem> updatePlanMilestone(
    String milestoneId, {
    String? title,
    String? description,
    int? priority,
    String? status,
    bool? active,
  }) async {
    milestoneUpdates.add(milestoneId);
    return PlanMilestoneMemoryItem(
      id: milestoneId,
      planId: 'plan-1',
      title: title ?? 'Updated milestone',
      description: description,
      milestoneType: 'checkpoint',
      priority: priority ?? 3,
      status: status ?? 'open',
      active: active ?? true,
    );
  }

  @override
  Future<void> archivePlanMilestone(String milestoneId) async {}
}

List<MemoryItem> _filterMemories(
  List<MemoryItem> memories, {
  required MemoryType? memoryType,
  required bool? active,
}) {
  return memories
      .where((memory) {
        if (memoryType != null && memory.memoryType != memoryType) {
          return false;
        }
        if (active != null && memory.active != active) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

List<T> _filterActive<T>(
  List<T> items,
  bool? active,
  bool Function(T item) isActive,
) {
  if (active == null) {
    return items;
  }
  return items
      .where((item) => isActive(item) == active)
      .toList(growable: false);
}
