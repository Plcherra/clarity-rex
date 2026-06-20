import 'package:clarity/rex/memory/data/memory_api.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/pages/memory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpMemoryPage(
  WidgetTester tester,
  MemoryPageFakeMemoryApi api,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [memoryApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: MemoryPage()),
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
  await tester.tap(find.byTooltip('Memory actions').first);
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

  @override
  Future<List<MemoryItem>> getMemories({
    MemoryType? memoryType,
    bool? active,
    int limit = 50,
  }) async {
    if (loadError != null) {
      throw loadError!;
    }
    return [
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
    ];
  }

  @override
  Future<List<PersonMemoryItem>> getPeople({
    bool? active,
    int limit = 50,
  }) async {
    return [
      PersonMemoryItem(
        id: 'person-1',
        displayName: 'Ana',
        relationship: 'friend',
        summary: 'A trusted reviewer for product ideas.',
        aliases: const [],
        importance: 3,
        status: 'active',
        active: true,
        metadata: const {},
        createdAt: DateTime.utc(2026, 5, 30),
        updatedAt: DateTime.utc(2026, 5, 31, 12),
      ),
    ];
  }

  @override
  Future<List<RuleMemoryItem>> getRules({bool? active, int limit = 50}) async {
    return [
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
  }

  @override
  Future<List<PlanMemoryItem>> getPlans({bool? active, int limit = 50}) async {
    return [
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
  }

  @override
  Future<List<CommitmentMemoryItem>> getCommitments({
    bool? active,
    int limit = 50,
  }) async {
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
