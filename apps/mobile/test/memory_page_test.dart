import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/memory/data/memory_constants.dart';
import 'package:clarity/rex/memory/data/memory_paged_result.dart';

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
    expect(find.text('Location: Somerville'), findsNothing);
    expect(find.text('Birthday: June 18'), findsNothing);
    expect(find.text('Workplace: Bom Dough'), findsNothing);
    // Importance / dates / extra chips stay out of the lean list row.
    expect(
      find.text('Important date: Launch review: 2026-06-20'),
      findsNothing,
    );
    expect(find.textContaining('Updated 05/31/2026'), findsNothing);
    expect(find.textContaining('Bank of America'), findsNothing);
    expect(find.textContaining('payroll'), findsNothing);

    expect(find.text('My name is Pedro Martins.'), findsNothing);
    expect(find.text('Structured memory'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Pedro is building Clarity.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Pedro is building Clarity.'), findsOneWidget);
    expect(find.text('Fact'), findsWidgets);
    expect(find.text('Preference'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Pedro prefers email updates.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Pedro prefers email updates.'), findsOneWidget);

    // Goals/plans live on the Goals tab only — not in Knows.
    expect(find.text('Ship Plaid review'), findsNothing);
    expect(find.text('Goals'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('MFA was enabled successfully.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('MFA was enabled successfully.'), findsOneWidget);
    expect(find.text('Somerville'), findsWidgets);
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
    expect(find.text('User lives in Somerville.'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Preferences'));
    await tester.pumpAndSettle();

    expect(find.text('Pedro prefers email updates.'), findsOneWidget);
    expect(listTileText('Pedro Martins'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'People'));
    await tester.pumpAndSettle();

    expect(listTileText('Pedro Martins'), findsOneWidget);
    expect(find.text('My name is Pedro Martins.'), findsNothing);
    expect(find.text('Pedro prefers email updates.'), findsNothing);
  });

  testWidgets(
    'MemoryPage active-only toggle applies to flat and people records',
    (tester) async {
      final api = MemoryPageFakeMemoryApi();

      await pumpMemoryPage(tester, api);

      expect(api.memoryActiveFilters.last, isTrue);
      expect(api.entityActiveFilters.last, isTrue);
      expect(find.text('Inactive flat fallback memory.'), findsNothing);
      expect(listTileText('Inactive Person'), findsNothing);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(api.memoryActiveFilters.last, isNull);
      expect(api.entityActiveFilters.last, isNull);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
      await tester.pumpAndSettle();

      expect(find.text('Inactive Person'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Inactive flat fallback memory.'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Inactive flat fallback memory.'), findsOneWidget);
    },
  );

  testWidgets('MemoryPage shows truncation banner when a list hits the limit', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final api = MemoryPageFakeMemoryApi(truncateLists: true);

    await pumpMemoryPage(tester, api);

    expect(find.text(l10n.memoryOverviewTruncated), findsOneWidget);
    expect(find.text(l10n.memoryOverviewLoadMore), findsOneWidget);

    await tester.tap(find.text(l10n.memoryOverviewLoadMore));
    await tester.pumpAndSettle();

    expect(api.memoryListLimits, [50, 50]);
    expect(find.text(l10n.memoryOverviewLoadMore), findsNothing);
  });

  testWidgets('MemoryPage does not show Goals or plan cards in Knows', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    expect(find.text('Ship Plaid review'), findsNothing);
    expect(find.textContaining('Submit compliance docs'), findsNothing);
    expect(find.text('Goals'), findsNothing);
  });

  testWidgets('MemoryPage place rows stay lean without event chip chrome', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await tester.scrollUntilVisible(
      find.text('Somerville'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Somerville'), findsWidgets);
    expect(find.text('Home city.'), findsOneWidget);
    expect(find.textContaining('Moved to Somerville'), findsNothing);
  });

  testWidgets('MemoryPage flat edit sheet shows updated date without importance', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();
    final l10n = lookupAppLocalizations(const Locale('en'));

    await pumpMemoryPage(tester, api);

    await tester.scrollUntilVisible(
      find.text('Pedro is building Clarity.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro is building Clarity.'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.memoryEditEditMemoryTitle), findsOneWidget);
    expect(find.text(l10n.commonImportance), findsNothing);
    expect(find.textContaining('Updated 05/31/2026'), findsOneWidget);
  });

  testWidgets('MemoryPage shows create affordance when AppBar is hidden', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();
    final l10n = lookupAppLocalizations(const Locale('en'));

    await pumpMemoryPage(tester, api, showAppBar: false);

    expect(find.byTooltip(l10n.memoryCreateAddTooltip), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.memoryCreateAddTooltip));
    await tester.pumpAndSettle();

    expect(find.text(l10n.memoryCreateChooseType), findsOneWidget);
    // List rows also show type labels like "Fact"; scope to create ListTiles.
    expect(
      find.widgetWithText(ListTile, l10n.memoryCreateFact),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ListTile, l10n.commonPerson),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ListTile, l10n.memoryCreateRule),
      findsOneWidget,
    );
    expect(find.text(l10n.memoryCreatePlan), findsNothing);
  });
}
