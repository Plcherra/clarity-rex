import 'package:clarity/features/assistant/memory/data/memory_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_page_test_helpers.dart';

void main() {
  testWidgets('MemoryPage can approve a pending candidate', (tester) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.approvedIds, ['candidate-1']);
    expect(find.text('No pending memory review'), findsOneWidget);
    expect(find.text('Saved to what Rex knows'), findsOneWidget);
  });

  testWidgets('MemoryPage can edit a pending candidate before approval', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Edit first'));
    await tester.pumpAndSettle();

    expect(find.text('Edit memory review'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).at(1),
      'Pedro prefers concise email updates.',
    );
    await tester.enterText(
      find.byType(TextField).at(2),
      'Pedro edited this before saving.',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.updatedCandidateId, 'candidate-1');
    expect(api.updatedCandidatePayload, {
      'content': 'Pedro prefers concise email updates.',
    });
    expect(api.updatedCandidateReason, 'Pedro edited this before saving.');
    expect(find.text('Memory review updated'), findsOneWidget);
    expect(
      find.text('Memory note: Pedro prefers concise email updates.'),
      findsOneWidget,
    );
  });

  testWidgets('MemoryPage filters pending corrections and keeps search text', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi(includeCorrectionCandidate: true);

    await pumpMemoryPage(tester, api);

    await tester.enterText(find.byType(TextField), 'email');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Memory note: Pedro prefers email'), findsOneWidget);

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
    expect(find.text('Memory note: Pedro prefers email'), findsNothing);
  });

  testWidgets('MemoryPage sends edited memory payload', (tester) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await openFirstMemoryActions(tester);
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
}
