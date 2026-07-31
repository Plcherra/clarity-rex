import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_page_test_helpers.dart';

void main() {
  testWidgets('MemoryPage create flow saves a fact after backend confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await tester.tap(find.byTooltip('Add saved information'));
    await tester.pumpAndSettle();

    expect(find.text('What should Clarity remember?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Fact'));
    await tester.pumpAndSettle();

    expect(find.text('Add a fact'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Summary'),
      'Pedro prefers morning walks.',
    );
    await tester.tap(find.text('Save to Knows'));
    await tester.pumpAndSettle();

    expect(api.createMemoryContent, 'Pedro prefers morning walks.');
    expect(find.text('Saved to Knows'), findsOneWidget);
  });

  testWidgets('MemoryPage create flow saves a person after backend confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await tester.tap(find.byTooltip('Add saved information'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Person'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Clara');
    await tester.tap(find.text('Save to Knows'));
    await tester.pumpAndSettle();

    expect(api.createPersonNameValue, 'Clara');
    expect(find.text('Person saved'), findsOneWidget);
  });
}
