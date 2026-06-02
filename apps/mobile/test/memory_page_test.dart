import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_page_test_helpers.dart';

void main() {
  testWidgets('MemoryPage separates saved memory from pending review', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending (1)'));
    await tester.pumpAndSettle();

    expect(find.text('1 item to review before saving'), findsOneWidget);
    expect(find.text('Memory note: Pedro prefers email'), findsOneWidget);
    expect(find.text('long_term_memory: Pedro prefers email'), findsNothing);
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Medium risk'), findsOneWidget);
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
