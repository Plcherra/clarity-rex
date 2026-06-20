import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_page_test_helpers.dart';

void main() {
  testWidgets('MemoryPage shows only what Clarity knows', (tester) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    expect(find.text('What Clarity Knows'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('People'), findsWidgets);
    expect(find.text('Pending'), findsNothing);
    expect(find.text('Corrections'), findsNothing);
    expect(listTileText('Pedro Martins'), findsOneWidget);
    expect(find.text('Location: Somerville'), findsOneWidget);
    expect(find.text('Birthday: June 18'), findsOneWidget);
    expect(find.text('Workplace: Bom Dough'), findsOneWidget);
    expect(
      find.text('Important date: Launch review: 2026-06-20'),
      findsOneWidget,
    );
    expect(find.textContaining('Bank of America'), findsNothing);
    expect(find.textContaining('payroll'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('My name is Pedro Martins.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('My name is Pedro Martins.'), findsOneWidget);
    expect(find.text('Updated 05/31/2026'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Pedro is building Clarity.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Facts'), findsWidgets);
    expect(find.text('Preferences'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Pedro prefers email updates.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Pedro prefers email updates.'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Goals'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Events'), findsWidgets);
    expect(find.text('Other'), findsNothing);
  });

  testWidgets('MemoryPage searches and filters saved memory groups', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await tester.enterText(find.byType(TextField), 'Somerville');
    await tester.pumpAndSettle();

    expect(listTileText('Pedro Martins'), findsOneWidget);
    expect(find.text('Pedro prefers email updates.'), findsNothing);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('User lives in Somerville.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Preferences'));
    await tester.pumpAndSettle();

    expect(find.text('Pedro prefers email updates.'), findsOneWidget);
    expect(listTileText('Pedro Martins'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'People'));
    await tester.pumpAndSettle();

    expect(listTileText('Pedro Martins'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('My name is Pedro Martins.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('My name is Pedro Martins.'), findsOneWidget);
    expect(find.text('Pedro prefers email updates.'), findsNothing);
  });

  testWidgets(
    'MemoryPage active-only toggle applies to flat and people records',
    (tester) async {
      final api = MemoryPageFakeMemoryApi();

      await pumpMemoryPage(tester, api);

      expect(api.memoryActiveFilters.last, isTrue);
      expect(api.peopleActiveFilters.last, isTrue);
      expect(find.text('Inactive flat fallback memory.'), findsNothing);
      expect(listTileText('Inactive Person'), findsNothing);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(api.memoryActiveFilters.last, isNull);
      expect(api.peopleActiveFilters.last, isNull);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
      await tester.pumpAndSettle();

      expect(find.text('Inactive Person'), findsOneWidget);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Inactive flat fallback memory.'), findsOneWidget);
    },
  );
}
