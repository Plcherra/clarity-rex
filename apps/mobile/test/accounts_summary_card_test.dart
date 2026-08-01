import 'package:clarity/app/ui_dependencies.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/accounts/presentation/widgets/accounts_header.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  testWidgets('AccountsSummaryCard leads with total balance', (tester) async {
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

    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('−\$315.58'), findsOneWidget);
    expect(find.text('2 connected accounts'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(
      find.textContaining('Activity this month — not the same as balance'),
      findsOneWidget,
    );
    expect(find.text('monthly net'), findsNothing);
  });
}
