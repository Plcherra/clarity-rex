import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_available_months.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/finance/application/financial_read_model_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('available months include current month and sort newest first', () {
    final months = dashboardAvailableYearMonths(
      transactionDates: const <DateTime>[],
      now: DateTime(2026, 8, 8),
    );
    // Empty txs still expose the current month.
    expect(months, ['2026-08']);

    final withHistory = dashboardAvailableYearMonths(
      transactionDates: [
        DateTime(2026, 6, 2),
        DateTime(2026, 7, 15),
        DateTime(2026, 7, 20),
      ],
      now: DateTime(2026, 8, 8),
    );
    expect(withHistory, ['2026-08', '2026-07', '2026-06']);
  });

  test('dashboard snapshot top categories follow the selected reference month', () {
    final model = FinancialReadModel(
      accounts: const [
        Account(id: 'checking', name: 'Checking', type: AccountType.checking),
      ],
      transactionRecords: const [],
      transactions: [
        Transaction(
          date: DateTime(2026, 7, 10),
          description: 'July Coffee',
          amount: -20,
          accountId: 'checking',
          categoryLabel: 'Coffee / Quick Food',
        ),
        Transaction(
          date: DateTime(2026, 8, 7),
          description: 'Sityodtong Inc',
          amount: -159,
          accountId: 'checking',
          categoryLabel: 'Fitness',
        ),
      ],
      budgets: const [],
    );

    final july = model.dashboardSnapshot(
      scope: const GlobalDashboardScope(),
      reference: DateTime(2026, 7, 1),
    );
    final august = model.dashboardSnapshot(
      scope: const GlobalDashboardScope(),
      reference: DateTime(2026, 8, 1),
    );

    expect(july.referenceMonth.month, 7);
    expect(july.topCategories.single.name, 'Coffee / Quick Food');
    expect(july.topCategories.single.amount, 20);

    expect(august.referenceMonth.month, 8);
    expect(august.topCategories.single.name, 'Fitness');
    expect(august.topCategories.single.amount, 159);
  });
}
