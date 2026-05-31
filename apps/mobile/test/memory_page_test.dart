import 'package:clarity/features/assistant/memory/data/memory_api.dart';
import 'package:clarity/features/assistant/memory/data/memory_models.dart';
import 'package:clarity/features/assistant/memory/presentation/pages/memory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MemoryPage separates saved memory from pending review', (
    tester,
  ) async {
    final api = _FakeMemoryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MemoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Preferences'), findsWidgets);
    expect(find.text('Pedro prefers email updates.'), findsOneWidget);
    expect(find.text('Updated 05/31/2026'), findsWidgets);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('People & places'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Other memories'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending (1)'));
    await tester.pumpAndSettle();

    expect(find.text('1 memory request waiting'), findsOneWidget);
    expect(find.text('Memory: Pedro prefers email'), findsOneWidget);
    expect(find.text('long_term_memory: Pedro prefers email'), findsNothing);
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Medium risk'), findsOneWidget);
  });

  testWidgets('MemoryPage can approve a pending candidate', (tester) async {
    final api = _FakeMemoryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MemoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(api.approvedIds, ['candidate-1']);
    expect(find.text('No pending memory review'), findsOneWidget);
    expect(find.text('Memory saved'), findsOneWidget);
  });

  testWidgets('MemoryPage can edit a pending candidate before approval', (
    tester,
  ) async {
    final api = _FakeMemoryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MemoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Edit first'));
    await tester.pumpAndSettle();

    expect(find.text('Edit memory request'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).at(1),
      'Pedro prefers concise email updates.',
    );
    await tester.enterText(
      find.byType(TextField).at(2),
      'Pedro edited this before saving.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(api.updatedCandidateId, 'candidate-1');
    expect(api.updatedCandidatePayload, {
      'content': 'Pedro prefers concise email updates.',
    });
    expect(api.updatedCandidateReason, 'Pedro edited this before saving.');
    expect(find.text('Memory request updated'), findsOneWidget);
    expect(
      find.text('Memory: Pedro prefers concise email updates.'),
      findsOneWidget,
    );
  });

  testWidgets('MemoryPage searches and filters saved memory groups', (
    tester,
  ) async {
    final api = _FakeMemoryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MemoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pumpAndSettle();

    expect(_listTileText('Ana'), findsOneWidget);
    expect(find.text('Pedro prefers email updates.'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Preferences'));
    await tester.pumpAndSettle();

    expect(find.text('Pedro prefers email updates.'), findsOneWidget);
    expect(_listTileText('Ana'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'People'));
    await tester.pumpAndSettle();

    expect(_listTileText('Ana'), findsOneWidget);
    expect(find.text('Pedro prefers email updates.'), findsNothing);
  });

  testWidgets('MemoryPage filters pending corrections and keeps search text', (
    tester,
  ) async {
    final api = _FakeMemoryApi(includeCorrectionCandidate: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MemoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'email');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Memory: Pedro prefers email'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Saved'));
    await tester.pumpAndSettle();

    expect(find.text('Pedro prefers email updates.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'email',
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Corrections'));
    await tester.pumpAndSettle();

    expect(find.text('No matching memories'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(
      find.text('Correction: replace "Flowfirst" with "FlowForce"'),
      findsOneWidget,
    );
    expect(find.text('Memory: Pedro prefers email'), findsNothing);
  });

  testWidgets('MemoryPage sends edited memory payload', (tester) async {
    final api = _FakeMemoryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MemoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await _openFirstMemoryActions(tester);
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Pedro prefers concise email updates.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(api.updatedMemoryId, 'memory-2');
    expect(api.updatedContent, 'Pedro prefers concise email updates.');
    expect(api.updatedMemoryType, MemoryType.fact);
    expect(find.text('Memory updated'), findsOneWidget);
  });

  testWidgets('MemoryPage does not archive when confirmation is cancelled', (
    tester,
  ) async {
    final api = _FakeMemoryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MemoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await _openFirstMemoryActions(tester);
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();

    expect(find.text('Archive memory?'), findsOneWidget);
    expect(
      find.text(
        'Rex will stop using this memory in future conversations. It will remain in memory history.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(api.archivedMemoryIds, isEmpty);
    expect(find.text('Pedro prefers email updates.'), findsOneWidget);
  });

  testWidgets('MemoryPage archives only after confirmation', (tester) async {
    final api = _FakeMemoryApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MemoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await _openFirstMemoryActions(tester);
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(api.archivedMemoryIds, ['memory-2']);
    expect(find.text('Pedro is building Clarity.'), findsNothing);
    expect(find.text('Memory archived'), findsOneWidget);
  });

  testWidgets('MemoryPage shows retryable copy for load failures', (
    tester,
  ) async {
    final api = _FakeMemoryApi(
      loadError: const MemoryApiException(
        'Supabase stack trace with private memory metadata',
        statusCode: 503,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MemoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not load Rex Memory. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Supabase stack trace'), findsNothing);
    expect(find.textContaining('private memory metadata'), findsNothing);
  });

  testWidgets('MemoryPage shows non-retryable copy when memory is gone', (
    tester,
  ) async {
    final api = _FakeMemoryApi(
      archiveError: const MemoryApiException(
        'Memory not found: memory-2',
        statusCode: 404,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoryApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: MemoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await _openFirstMemoryActions(tester);
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(find.text('That memory is no longer available.'), findsWidgets);
    expect(find.textContaining('memory-2'), findsNothing);
  });
}

Finder _listTileText(String text) {
  return find.descendant(of: find.byType(ListTile), matching: find.text(text));
}

Future<void> _openFirstMemoryActions(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Memory actions').first);
  await tester.pumpAndSettle();
}

class _FakeMemoryApi extends MemoryApi {
  _FakeMemoryApi({
    this.includeCorrectionCandidate = false,
    this.loadError,
    this.archiveError,
  });

  final bool includeCorrectionCandidate;
  final Object? loadError;
  final Object? archiveError;
  final approvedIds = <String>[];
  final rejectedIds = <String>[];
  final archivedMemoryIds = <String>[];
  String? updatedMemoryId;
  String? updatedContent;
  MemoryType? updatedMemoryType;
  String? updatedCandidateId;
  Map<String, dynamic>? updatedCandidatePayload;
  String? updatedCandidateReason;
  var _candidatePending = true;

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
  Future<List<PendingMemoryCandidateItem>> getMemoryCandidates({
    String status = 'pending',
    int limit = 50,
  }) async {
    if (!_candidatePending) {
      return const [];
    }
    return [
      PendingMemoryCandidateItem.fromJson({
        'id': 'candidate-1',
        'candidate_type': 'long_term_memory',
        'status': 'pending',
        'risk_level': 'medium',
        'preview': 'long_term_memory: Pedro prefers email',
        'reason': 'Rex heard this preference in chat.',
        'payload': {'content': 'Pedro prefers email'},
      }),
      if (includeCorrectionCandidate)
        PendingMemoryCandidateItem.fromJson({
          'id': 'candidate-2',
          'candidate_type': 'correction',
          'status': 'pending',
          'risk_level': 'high',
          'preview': 'correction: FlowForce spelling',
          'reason': 'Pedro corrected the product name.',
          'payload_preview': {
            'intent': {
              'old_value': 'Flowfirst',
              'new_value': 'FlowForce',
              'target_hint': 'product name',
            },
          },
        }),
    ];
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

  @override
  Future<PendingMemoryCandidateItem> approveMemoryCandidate(
    String candidateId,
  ) async {
    approvedIds.add(candidateId);
    _candidatePending = false;
    return PendingMemoryCandidateItem.fromJson({
      'id': candidateId,
      'candidate_type': 'long_term_memory',
      'status': 'applied',
      'risk_level': 'medium',
      'preview': 'long_term_memory: Pedro prefers email',
    });
  }

  @override
  Future<PendingMemoryCandidateItem> updateMemoryCandidate(
    String candidateId, {
    Map<String, dynamic>? payload,
    String? reason,
  }) async {
    updatedCandidateId = candidateId;
    updatedCandidatePayload = payload;
    updatedCandidateReason = reason;
    return PendingMemoryCandidateItem.fromJson({
      'id': candidateId,
      'candidate_type': 'long_term_memory',
      'status': 'pending',
      'risk_level': 'medium',
      'preview': 'long_term_memory: ${payload?['content']}',
      'reason': reason,
      'payload': payload ?? const {},
    });
  }

  @override
  Future<PendingMemoryCandidateItem> rejectMemoryCandidate(
    String candidateId,
  ) async {
    rejectedIds.add(candidateId);
    _candidatePending = false;
    return PendingMemoryCandidateItem.fromJson({
      'id': candidateId,
      'candidate_type': 'long_term_memory',
      'status': 'rejected',
      'risk_level': 'medium',
      'preview': 'long_term_memory: Pedro prefers email',
    });
  }
}
