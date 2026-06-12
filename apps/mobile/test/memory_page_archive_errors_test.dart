import 'package:clarity/rex/memory/data/memory_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_page_test_helpers.dart';

void main() {
  testWidgets('MemoryPage does not archive when confirmation is cancelled', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await openFirstMemoryActions(tester);
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();

    expect(find.text('Archive saved information?'), findsOneWidget);
    expect(
      find.text(
        'This saved information will stop being used in future conversations. It will remain in information history.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(api.archivedMemoryIds, isEmpty);
    expect(find.text('Pedro prefers email updates.'), findsOneWidget);
  });

  testWidgets('MemoryPage archives only after confirmation', (tester) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await openFirstMemoryActions(tester);
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
    final api = MemoryPageFakeMemoryApi(
      loadError: const MemoryApiException(
        'Supabase stack trace with private memory metadata',
        statusCode: 503,
      ),
    );

    await pumpMemoryPage(tester, api);

    expect(
      find.text(
        'Could not load saved information. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Supabase stack trace'), findsNothing);
    expect(find.textContaining('private memory metadata'), findsNothing);
  });

  testWidgets('MemoryPage shows non-retryable copy when memory is gone', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi(
      archiveError: const MemoryApiException(
        'Memory not found: memory-2',
        statusCode: 404,
      ),
    );

    await pumpMemoryPage(tester, api);

    await openFirstMemoryActions(tester);
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(find.text('That memory is no longer available.'), findsWidgets);
    expect(find.textContaining('memory-2'), findsNothing);
  });
}
