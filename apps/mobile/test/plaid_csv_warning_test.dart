import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/accounts/presentation/csv_plaid_duplicate_warning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  testWidgets('connected account CSV warning explains duplicate risk', (
    tester,
  ) async {
    bool? result;
    const account = Account(
      id: 'account-1',
      name: 'Everyday Checking',
      type: AccountType.checking,
      source: 'plaid',
      plaidItemId: 'item-1',
    );

    await tester.pumpWidget(
      wrapWithL10n(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await confirmCsvImportForPlaidAccount(context, account);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Import CSV into connected account?'), findsOneWidget);
    expect(find.textContaining('duplicate rows'), findsOneWidget);

    await tester.tap(find.text('Continue import'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
