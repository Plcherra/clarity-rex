import 'package:clarity/features/profile/application/locale_controller.dart';
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
  MemoryPageFakeMemoryApi({this.loadError, this.archiveError});

  final Object? loadError;
  final Object? archiveError;
  final archivedMemoryIds = <String>[];
  String? updatedMemoryId;
  String? updatedContent;
  MemoryType? updatedMemoryType;
  final memoryActiveFilters = <bool?>[];
  final peopleActiveFilters = <bool?>[];
  final ruleActiveFilters = <bool?>[];
  final planActiveFilters = <bool?>[];
  final commitmentActiveFilters = <bool?>[];
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
    int limit = 50,
  }) async {
    if (loadError != null) {
      throw loadError!;
    }
    memoryActiveFilters.add(active);
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

  @override
  Future<List<PersonMemoryItem>> getPeople({
    bool? active,
    int limit = 50,
  }) async {
    peopleActiveFilters.add(active);
    final people = [
      PersonMemoryItem(
        id: 'person-1',
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
      PersonMemoryItem(
        id: 'person-inactive',
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
    ];
    return _filterActive(people, active, (person) => person.active);
  }

  @override
  Future<List<RuleMemoryItem>> getRules({bool? active, int limit = 50}) async {
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
  Future<List<PlanMemoryItem>> getPlans({bool? active, int limit = 50}) async {
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
  Future<List<CommitmentMemoryItem>> getCommitments({
    bool? active,
    int limit = 50,
  }) async {
    commitmentActiveFilters.add(active);
    return const [];
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
