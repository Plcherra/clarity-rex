import 'package:clarity/app/ui_dependencies.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/accounts/data/plaid_account_service.dart';
import 'package:clarity/features/accounts/presentation/widgets/plaid_account_tile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

Future<void> _pumpPlaidAccountTile(
  WidgetTester tester,
  PlaidAccountTile tile,
) async {
  await tester.pumpWidget(wrapWithL10nScaffold(tile));
}

void main() {
  testWidgets(
    'PlaidAccountTile shows synced account overview without transaction previews',
    (tester) async {
      await _pumpPlaidAccountTile(
        tester,
        PlaidAccountTile(
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
              ),
              status: PlaidAccountConnectionStatus.connected,
              lastSyncedAt: DateTime.now(),
              onResync: () {},
              onDisconnect: () {},
              onTap: () {},
        ),
      );

      expect(find.text('Bank of Test Checking • 1234'), findsOneWidget);
      expect(find.text('Everyday Checking'), findsOneWidget);
      expect(find.text('\$1,200.50'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('Available \$1,000.25'), findsOneWidget);
      expect(find.text('Recent transactions'), findsNothing);
      expect(find.text('Plaid'), findsOneWidget);
    },
  );

  testWidgets(
    'PlaidAccountTile composes clear names for generic Plaid account labels',
    (tester) async {
      await _pumpPlaidAccountTile(
        tester,
        PlaidAccountTile(
              item: const AccountOverviewItem(
                account: Account(
                  id: 'account-1',
                  name: 'depository Account 3279',
                  type: AccountType.checking,
                  institution: 'Capital One',
                  currentBalance: 764.50,
                  source: 'plaid',
                  plaidItemId: 'item-1',
                  plaidInstitutionName: 'Capital One',
                  plaidAccountMask: '3279',
                  plaidAvailableBalance: 764.50,
                ),
                availableThisMonth: 0,
                incomeThisMonth: 0,
                spentThisMonth: 0,
                statementBalance: 764.50,
                netCashFlow: 0,
              ),
              status: PlaidAccountConnectionStatus.connected,
              lastSyncedAt: null,
              onResync: () {},
              onDisconnect: () {},
              onTap: () {},
        ),
      );

      expect(find.text('Capital One Checking • 3279'), findsOneWidget);
      expect(find.text('depository Account 3279'), findsNothing);
    },
  );

  testWidgets(
    'PlaidAccountTile moves Plaid product names into supporting detail',
    (tester) async {
      await _pumpPlaidAccountTile(
        tester,
        PlaidAccountTile(
              item: const AccountOverviewItem(
                account: Account(
                  id: 'account-1',
                  name: 'Customized Cash Rewards',
                  type: AccountType.creditCard,
                  institution: 'Bank of America',
                  source: 'plaid',
                  plaidItemId: 'item-1',
                  plaidInstitutionName: 'Bank of America',
                  plaidAccountMask: '5050',
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
              onDisconnect: () {},
              onTap: () {},
        ),
      );

      expect(find.text('Bank of America Credit Card • 5050'), findsOneWidget);
      expect(find.text('Customized Cash Rewards'), findsOneWidget);
    },
  );

  testWidgets(
    'PlaidAccountTile keeps mixed-source transactions out of the account overview',
    (tester) async {
      await _pumpPlaidAccountTile(
        tester,
        PlaidAccountTile(
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
              ),
              status: PlaidAccountConnectionStatus.connected,
              lastSyncedAt: null,
              onResync: () {},
              onDisconnect: () {},
              onTap: () {},
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
    await _pumpPlaidAccountTile(
      tester,
      PlaidAccountTile(
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
            onDisconnect: () {},
            onTap: () {},
      ),
    );

    expect(find.text('Everyday Checking'), findsOneWidget);
    expect(find.text('No synced transactions yet.'), findsNothing);
  });

  testWidgets('PlaidAccountTile exposes disconnect for active connections', (
    tester,
  ) async {
    var disconnected = false;
    await _pumpPlaidAccountTile(
      tester,
      PlaidAccountTile(
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
            onDisconnect: () => disconnected = true,
            onTap: () {},
      ),
    );

    await tester.tap(find.byTooltip('Disconnect bank'));

    expect(disconnected, isTrue);
  });

  testWidgets('PlaidAccountTile hides disconnect for disconnected accounts', (
    tester,
  ) async {
    await _pumpPlaidAccountTile(
      tester,
      PlaidAccountTile(
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
            status: PlaidAccountConnectionStatus.disconnected,
            lastSyncedAt: null,
            onResync: () {},
            onDisconnect: () {},
            onTap: () {},
      ),
    );

    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.byTooltip('Disconnect bank'), findsNothing);
    expect(find.byTooltip('Disconnected'), findsOneWidget);
  });

  testWidgets('PlaidAccountTile explains login-required recovery', (
    tester,
  ) async {
    await _pumpPlaidAccountTile(
      tester,
      PlaidAccountTile(
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
            status: PlaidAccountConnectionStatus.loginRequired,
            lastSyncedAt: null,
            onResync: () {},
            onDisconnect: () {},
            onTap: () {},
      ),
    );

    expect(find.text('Needs login'), findsOneWidget);
    expect(
      find.textContaining('Plaid needs you to sign in again'),
      findsOneWidget,
    );
    expect(find.byTooltip('Login required'), findsOneWidget);
  });

  testWidgets('PlaidAccountTile explains pending-expiration recovery', (
    tester,
  ) async {
    await _pumpPlaidAccountTile(
      tester,
      PlaidAccountTile(
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
            status: PlaidAccountConnectionStatus.pendingExpiration,
            lastSyncedAt: null,
            onResync: () {},
            onDisconnect: () {},
            onTap: () {},
      ),
    );

    expect(find.text('Expiring soon'), findsOneWidget);
    expect(
      find.textContaining('This Plaid connection may expire soon'),
      findsOneWidget,
    );
    expect(find.byTooltip('Expiring soon'), findsOneWidget);
  });

  testWidgets('PlaidAccountTile explains stale webhook delay', (tester) async {
    await _pumpPlaidAccountTile(
      tester,
      PlaidAccountTile(
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
            lastSyncedAt: DateTime.now(),
            webhookLastReceivedAt: DateTime.now().subtract(
              const Duration(days: 2),
            ),
            onResync: () {},
            onDisconnect: () {},
            onTap: () {},
      ),
    );

    expect(find.textContaining('No recent Plaid webhook'), findsOneWidget);
    expect(find.textContaining('2d ago'), findsOneWidget);
  });

  testWidgets(
    'PlaidAccountTile shows leftover credit from limit when available copies owed',
    (tester) async {
      await _pumpPlaidAccountTile(
        tester,
        PlaidAccountTile(
          item: const AccountOverviewItem(
            account: Account(
              id: 'cap-card',
              name: 'Quicksilver',
              type: AccountType.creditCard,
              institution: 'Capital One',
              currentBalance: 270.68,
              source: 'plaid',
              plaidItemId: 'item-1',
              plaidInstitutionName: 'Capital One',
              plaidAccountMask: '1234',
              plaidAvailableBalance: 270.68,
              plaidCreditLimit: 900,
            ),
            availableThisMonth: 0,
            incomeThisMonth: 0,
            spentThisMonth: 0,
            statementBalance: -270.68,
            netCashFlow: 0,
          ),
          status: PlaidAccountConnectionStatus.connected,
          lastSyncedAt: DateTime.now(),
          onResync: () {},
          onDisconnect: () {},
          onTap: () {},
        ),
      );

      expect(find.textContaining('Credit left'), findsOneWidget);
      expect(find.textContaining('\$629.32'), findsOneWidget);
    },
  );
}
