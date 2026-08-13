import 'package:clarity/app/ui_dependencies.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/accounts/presentation/widgets/accounts_header.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  testWidgets('AccountsSummaryCard leads with net balance, cash, and debt', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10nScaffold(
        AccountsSummaryCard(
          accounts: [
            AccountOverviewItem(
              account: const Account(
                id: 'checking',
                name: 'Checking',
                type: AccountType.checking,
                currentBalance: 100,
              ),
              availableThisMonth: 50,
              incomeThisMonth: 3000,
              spentThisMonth: 2950,
              statementBalance: 100,
              netCashFlow: 50,
            ),
            AccountOverviewItem(
              account: const Account(
                id: 'credit',
                name: 'Credit Card',
                type: AccountType.creditCard,
                currentBalance: 415.58,
                plaidAvailableBalance: 500,
              ),
              availableThisMonth: 0,
              incomeThisMonth: 0,
              spentThisMonth: 200,
              statementBalance: -415.58,
              netCashFlow: -200,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Net balance'), findsOneWidget);
    expect(find.text('Cash minus cards owed'), findsOneWidget);
    expect(find.text('−\$315.58'), findsOneWidget);
    expect(find.textContaining('Cash \$100.00'), findsOneWidget);
    expect(find.textContaining('Debt \$415.58'), findsOneWidget);
    expect(find.textContaining('Credit left \$500.00'), findsOneWidget);
    expect(find.text('2 connected accounts'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.textContaining('Left this month'), findsOneWidget);
    expect(
      find.textContaining("This month's leftover — not cash in the bank"),
      findsOneWidget,
    );
    expect(find.text('monthly net'), findsNothing);
  });
}
