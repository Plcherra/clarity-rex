import 'package:clarity/app/ui_dependencies.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/accounts/data/plaid_account_service.dart';
import 'package:clarity/features/accounts/presentation/widgets/plaid_account_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'PlaidAccountTile shows synced account overview without transaction previews',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaidAccountTile(
              item: AccountOverviewItem(
                account: Account(
                  id: 'account-1',
                  name: 'Everyday Checking',
                  type: AccountType.checking,
                  institution: 'Bank of Test',
                  currentBalance: 1200.50,
                  source: 'plaid',
                  plaidItemId: 'item-1',
                  plaidAccountMask: '1234',
                  plaidAvailableBalance: 1000.25,
                ),
                availableThisMonth: 900,
                incomeThisMonth: 1000,
                spentThisMonth: 100,
                statementBalance: 1200.50,
                netCashFlow: 900,
                recentTransactions: [
                  Transaction(
                    date: DateTime(2026, 6, 8),
                    description: 'Coffee Shop',
                    amount: -5.25,
                    accountId: 'account-1',
                    source: 'plaid',
                  ),
                  Transaction(
                    date: DateTime(2026, 6, 7),
                    description: 'Payroll',
                    amount: 500,
                    accountId: 'account-1',
                    source: 'plaid',
                  ),
                ],
              ),
              status: PlaidAccountConnectionStatus.connected,
              lastSyncedAt: DateTime.now(),
              onResync: () {},
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Everyday Checking'), findsOneWidget);
      expect(find.textContaining('**** 1234'), findsOneWidget);
      expect(find.text('Balance \$1,200.50'), findsOneWidget);
      expect(find.text('Available \$1,000.25'), findsOneWidget);
      expect(find.text('Recent transactions'), findsNothing);
      expect(find.text('Coffee Shop'), findsNothing);
      expect(find.text('Payroll'), findsNothing);
      expect(find.text('Plaid'), findsOneWidget);
    },
  );

  testWidgets(
    'PlaidAccountTile keeps mixed-source transactions out of the account overview',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaidAccountTile(
              item: AccountOverviewItem(
                account: const Account(
                  id: 'account-1',
                  name: 'Everyday Checking',
                  type: AccountType.checking,
                  source: 'plaid',
                  plaidItemId: 'item-1',
                ),
                availableThisMonth: 0,
                incomeThisMonth: 0,
                spentThisMonth: 0,
                statementBalance: null,
                netCashFlow: 0,
                recentTransactions: [
                  Transaction(
                    date: DateTime(2026, 6, 8),
                    description: 'Synced Coffee',
                    amount: -5.25,
                    accountId: 'account-1',
                    source: 'plaid',
                  ),
                  Transaction(
                    date: DateTime(2026, 6, 7),
                    description: 'CSV Grocery',
                    amount: -44.10,
                    accountId: 'account-1',
                    source: 'csv',
                    importId: 'csv-20260607',
                  ),
                ],
              ),
              status: PlaidAccountConnectionStatus.connected,
              lastSyncedAt: null,
              onResync: () {},
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Everyday Checking'), findsOneWidget);
      expect(find.text('Synced Coffee'), findsNothing);
      expect(find.text('CSV Grocery'), findsNothing);
      expect(find.text('Recent transactions'), findsNothing);
      expect(find.text('Manual/CSV'), findsNothing);
      expect(find.text('Plaid'), findsOneWidget);
    },
  );

  testWidgets('PlaidAccountTile handles empty synced transactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaidAccountTile(
            item: const AccountOverviewItem(
              account: Account(
                id: 'account-1',
                name: 'Everyday Checking',
                type: AccountType.checking,
                source: 'plaid',
                plaidItemId: 'item-1',
              ),
              availableThisMonth: 0,
              incomeThisMonth: 0,
              spentThisMonth: 0,
              statementBalance: null,
              netCashFlow: 0,
            ),
            status: PlaidAccountConnectionStatus.connected,
            lastSyncedAt: null,
            onResync: () {},
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Everyday Checking'), findsOneWidget);
    expect(find.text('No synced transactions yet.'), findsNothing);
  });
}
