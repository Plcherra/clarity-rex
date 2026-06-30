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
    expect(
      find.text('Important date: Launch review: 2026-06-20'),
      findsOneWidget,
    );
    expect(find.textContaining('Bank of America'), findsNothing);
    expect(find.textContaining('payroll'), findsNothing);

    expect(find.text('My name is Pedro Martins.'), findsNothing);
    expect(find.text('Structured memory'), findsNothing);
    expect(find.textContaining('Updated 05/31/2026'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Pedro is building Clarity.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Pedro is building Clarity.'), findsOneWidget);
    expect(find.textContaining('Fact ·'), findsWidgets);
    expect(find.textContaining('Preference ·'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Pedro prefers email updates.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Pedro prefers email updates.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Ship Plaid review'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Ship Plaid review'), findsOneWidget);

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

  testWidgets('MemoryPage shows plan milestone previews on plan cards', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await tester.scrollUntilVisible(
      find.textContaining('Submit compliance docs'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Submit compliance docs'), findsOneWidget);
  });

  testWidgets('MemoryPage shows entity event previews on place cards', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();

    await pumpMemoryPage(tester, api);

    await tester.scrollUntilVisible(
      find.textContaining('Moved to Somerville'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Moved to Somerville'), findsOneWidget);
  });

  testWidgets('MemoryPage can add a plan milestone from the plan card menu', (
    tester,
  ) async {
    final api = MemoryPageFakeMemoryApi();
    final l10n = lookupAppLocalizations(const Locale('en'));

    await pumpMemoryPage(tester, api);

    await openMemoryActionsForText(tester, 'Ship Plaid review');
    await tester.tap(find.text(l10n.memoryTileAddMilestone));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Collect audit logs');
    await tester.enterText(find.byType(TextField).at(1), 'Gather evidence pack');
    await tester.tap(find.text(l10n.memoryCreateSave));
    await tester.pumpAndSettle();

    expect(api.milestoneCreates, [
      {
        'planId': 'plan-1',
        'title': 'Collect audit logs',
        'description': 'Gather evidence pack',
      },
    ]);
    expect(find.text(l10n.memoryPageMilestoneCreated), findsOneWidget);
  });
}
