import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_page_test_helpers.dart';

void main() {
  testWidgets('MemoryPage shows only what Rex knows', (tester) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    expect(find.text('What Rex Knows'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
    expect(find.text('Corrections'), findsNothing);
    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Preferences'), findsWidgets);
    expect(find.text('Pedro prefers email updates.'), findsOneWidget);
    expect(find.text('Updated 05/31/2026'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('People & places'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('People & places'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Other memories'), findsNothing);
  });

  testWidgets('MemoryPage searches and filters saved memory groups', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pumpAndSettle();

    expect(listTileText('Ana'), findsOneWidget);
    expect(find.text('Pedro prefers email updates.'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Preferences'));
    await tester.pumpAndSettle();

    expect(find.text('Pedro prefers email updates.'), findsOneWidget);
    expect(listTileText('Ana'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'People'));
    await tester.pumpAndSettle();

    expect(listTileText('Ana'), findsOneWidget);
    expect(find.text('Pedro prefers email updates.'), findsNothing);
  });
}
