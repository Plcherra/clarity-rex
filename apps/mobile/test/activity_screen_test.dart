import 'dart:io';

import 'package:clarity/core/supabase/supabase_exceptions.dart';
import 'package:clarity/features/finance/data/financial_audit_service.dart';
import 'package:clarity/features/finance/presentation/activity_screen.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  FinancialAuditEvent sampleEvent() {
    return FinancialAuditEvent(
      id: 'evt-1',
      userId: 'user-1',
      eventType: 'transaction_category_updated',
      entityType: 'transaction',
      source: 'app',
      previousValue: const {'category_name': 'Food'},
      newValue: const {'category_name': 'Groceries'},
      metadata: const {},
      createdAt: DateTime.utc(2026, 8, 7, 15, 30),
    );
  }

  testWidgets('shows empty state when there are no events', (tester) async {
    var sawLimit = 0;
    DateTime? sawSince;
    await tester.pumpWidget(
      wrapWithL10n(
        ActivityScreen(
          loadEvents: ({required limit, required since}) async {
            sawLimit = limit;
            sawSince = since;
            return const [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.activityEmptyState), findsOneWidget);
    expect(sawLimit, 50);
    expect(sawSince, isNotNull);
  });

  testWidgets('shows readable titles for known audit events', (tester) async {
    await tester.pumpWidget(
      wrapWithL10n(
        ActivityScreen(
          loadEvents: ({required limit, required since}) async {
            return [sampleEvent()];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.categorySheetAuditTransactionCategoryChanged),
      findsOneWidget,
    );
    expect(find.textContaining('Food -> Groceries'), findsOneWidget);
  });

  testWidgets('shows honest error state when fetch fails', (tester) async {
    await tester.pumpWidget(
      wrapWithL10n(
        ActivityScreen(
          loadEvents: ({required limit, required since}) async {
            throw const SupabaseDataException(
              table: 'financial_audit_events',
              action: 'fetchRecent',
              message: 'Could not fetch financial audit events.',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.serviceErrorFetchAuditEvents), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsOneWidget);
    expect(find.text(l10n.activityEmptyState), findsNothing);
  });

  test('dashboard app bar wires Activity; Profile does not', () {
    final dashboard = File(
      'lib/features/dashboard/presentation/financial_dashboard_view.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/features/profile/presentation/profile_screen.dart',
    ).readAsStringSync();
    expect(dashboard, contains("ValueKey('dashboard_activity_button')"));
    expect(dashboard, contains('ActivityScreen'));
    expect(profile, isNot(contains('ActivityScreen')));
  });
}
