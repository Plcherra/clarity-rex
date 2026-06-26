import 'package:clarity/core/models/models.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/rex/data/financial_context_service.dart';
import 'package:clarity/rex/data/rex_financial_transaction_policy.dart';
import 'package:clarity/features/categories/domain/category_normalization.dart';
import 'package:clarity/features/finance/application/financial_read_model_service.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'assistant financial context intent gate skips casual and recall turns',
    () {
      expect(shouldAttachAssistantFinancialContext('Hey Rex'), isFalse);
      expect(
        shouldAttachAssistantFinancialContext("It's so hot up here."),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext('Yeah. Midsummer.'),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext('So what can you do?'),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext(
          'I worked with two new employees, Aaron and Jessica.',
        ),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext('Everyone got a good heart.'),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext(
          'Search old chats about Legacy of Kain',
        ),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext('What do you know about my mom?'),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext('Search chats about money'),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext('Did I mention sending money?'),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext(
          'Have we talked about Bom Dough payroll?',
        ),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext('What did I say about money?'),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext(
          'Can you help me balance work and rest?',
        ),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext('I saved that note for later.'),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext(
          'What is my Clarity account email?',
        ),
        isFalse,
      );
      expect(
        shouldAttachAssistantFinancialContext(
          'I was listening to \$uicideboy\$ earlier.',
        ),
        isFalse,
      );
    },
  );

  test('assistant financial context intent gate allows finance turns', () {
    expect(
      shouldAttachAssistantFinancialContext('How much did I spend this week?'),
      isTrue,
    );
    expect(
      shouldAttachAssistantFinancialContext('What is my bank balance?'),
      isTrue,
    );
    expect(
      shouldAttachAssistantFinancialContext('Show my Plaid transactions'),
      isTrue,
    );
    expect(
      shouldAttachAssistantFinancialContext('Search my transactions'),
      isTrue,
    );
    expect(
      shouldAttachAssistantFinancialContext('Can I afford rent this month?'),
      isTrue,
    );
    expect(
      shouldAttachAssistantFinancialContext('Did payroll hit my account?'),
      isTrue,
    );
    expect(
      shouldAttachAssistantFinancialContext('Did I send Jessica money?'),
      isTrue,
    );
    expect(
      shouldAttachAssistantFinancialContext('What accounts do I have?'),
      isTrue,
    );
    expect(
      shouldAttachAssistantFinancialContext('Do I have \$20 for gas?'),
      isTrue,
    );
  });

  test('Rex transaction context stays bounded and keeps newest rows', () {
    final records = [
      for (var i = 0; i < 150; i += 1)
        _record(
          id: 'tx-$i',
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          categoryId: i == 0 ? 'unknown' : 'food',
        ),
    ];
    final transactions = [
      for (final record in records)
        Transaction(
          date: record.date,
          description: record.description ?? '',
          amount: record.amount,
          accountId: record.accountId,
          categoryLabel: record.categoryId == 'unknown'
              ? kUnknownCategoryName
              : 'Food & Drink',
          fingerprint: record.id,
        ),
    ];
    final resolved = resolveTransactions(
      transactions,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {},
      allTransactions: transactions,
    );

    final selected = selectRexTransactionContextRows(
      transactions: records,
      resolvedTransactions: resolved,
      maxRows: 120,
    );

    expect(selected, hasLength(120));
    expect(selected.first.id, 'tx-149');
    expect(selected.map((record) => record.id), isNot(contains('tx-0')));
  });

  test(
    'Rex drilldown index summarizes months accounts and categories',
    () {
      const checking = Account(
        id: 'checking',
        name: 'Checking',
        type: AccountType.checking,
      );
      const card = Account(
        id: 'card',
        name: 'Visa',
        type: AccountType.creditCard,
      );
      final transactions = [
        Transaction(
          date: DateTime(2026, 3, 4),
          description: 'Coffee',
          amount: -8.25,
          accountId: checking.id,
          categoryLabel: 'Coffee / Quick Food',
          fingerprint: 'coffee',
        ),
        Transaction(
          date: DateTime(2026, 3, 5),
          description: 'Payroll',
          amount: 1500,
          accountId: checking.id,
          categoryLabel: 'Income / Payroll',
          fingerprint: 'payroll',
        ),
        Transaction(
          date: DateTime(2026, 4, 2),
          description: 'Unknown purchase',
          amount: -12,
          accountId: card.id,
          categoryLabel: kUnknownCategoryName,
          fingerprint: 'unknown',
        ),
      ];
      final resolved = resolveTransactions(
        transactions,
        categoryOverrides: const {},
        categoryDisplayRenamesLower: const {},
        accountsById: {checking.id: checking, card.id: card},
        allTransactions: transactions,
      );

      final index = buildRexDrilldownIndex(
        resolvedTransactions: resolved,
        accountsById: {checking.id: checking, card.id: card},
      );

      final months = index['months'] as List<Map<String, dynamic>>;
      expect(months.first['key'], '2026-04');
      expect(months.first['sample_transaction_ids'], contains('unknown'));

      final accounts = index['accounts'] as List<Map<String, dynamic>>;
      expect(accounts.map((item) => item['label']), contains('Checking'));
      expect(accounts.map((item) => item['label']), contains('Visa'));

      final categories = index['categories'] as List<Map<String, dynamic>>;
      expect(categories.map((item) => item['label']), isNot(contains('Other')));
      expect(
        categories.map((item) => item['label']),
        isNot(contains(kUnknownCategoryName)),
      );
      final coffee = categories.singleWhere(
        (item) => item['label'] == 'Coffee / Quick Food',
      );
      expect(coffee['spend'], 8.25);
      final shopping = categories.singleWhere(
        (item) => item['label'] == kBestEffortExpenseCategoryName,
      );
      expect(shopping['spend'], 12);
    },
  );

  test('Rex transaction context stays bounded with newest rows', () {
    final records = [
      for (var i = 0; i < 150; i += 1)
        _record(
          id: 'db-$i',
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          categoryId: i == 0 ? kUnknownCategoryName : 'food',
          description: i == 0 ? 'Uncategorized Plaid row' : 'Coffee $i',
          source: 'plaid',
          importedFromCsv: false,
        ),
    ];
    final transactions = [
      for (final record in records)
        Transaction(
          date: record.date,
          description: record.description ?? '',
          amount: -record.amount.abs(),
          accountId: record.accountId,
          categoryLabel: record.categoryId == kUnknownCategoryName
              ? kUnknownCategoryName
              : 'Food & Drink',
          fingerprint: 'plaid-${record.id}',
          source: record.source,
        ),
    ];
    final resolved = resolveTransactions(
      transactions,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: const {},
      accountsById: const {},
      allTransactions: transactions,
    );

    final selected = selectRexTransactionContextRows(
      transactions: records,
      resolvedTransactions: resolved,
      maxRows: 120,
    );

    expect(selected, hasLength(120));
    expect(selected.map((record) => record.id), isNot(contains('db-0')));
    expect(selected.first.id, 'db-149');
  });

  test(
    'Rex financial context reports degraded reads instead of empty truth',
    () async {
      final service = AssistantFinancialContextService(
        loadFinancialReadModel: () async => FinancialReadModel.empty(
          loadIssues: const [
            FinancialReadModelLoadIssue(
              source: 'transactions',
              message: 'Could not fetch transactions.',
            ),
          ],
        ),
        spendReference: () => DateTime(2026, 5, 26),
        notifyDataChanged: () {},
      );

      final summary = await service.buildSummary();
      final dataStatus = summary['data_status'] as Map<String, dynamic>;

      expect(dataStatus['state'], 'degraded');
      expect(dataStatus['financial_context_complete'], isFalse);
      expect(dataStatus['load_errors'], [
        {'source': 'transactions', 'message': 'Could not fetch transactions.'},
      ]);
      expect(
        (summary['integration']
            as Map<String, dynamic>)['full_financial_context_included'],
        isFalse,
      );
    },
  );

  test('Rex financial context has explicit unavailable fallback truth', () {
    final summary = AssistantFinancialContextService.unavailableSummary(
      source: 'mobile_financial_context_service',
      message: 'Financial context is not available.',
    );
    final dataStatus = summary['data_status'] as Map<String, dynamic>;
    final integration = summary['integration'] as Map<String, dynamic>;
    final controls = summary['available_controls'] as Map<String, dynamic>;

    expect(dataStatus['state'], 'unavailable');
    expect(dataStatus['financial_context_complete'], isFalse);
    expect(integration['assistant_can_reference_specific_records'], isFalse);
    expect(controls['categories'], isNot(contains('rename_category')));
    expect(
      controls['categories'],
      isNot(contains('assign_transaction_category')),
    );
  });

  test(
    'What accounts do I have includes Plaid account truth from Clarity',
    () async {
      final summary = await _buildPlaidTruthSummary();
      final accounts = summary['accounts'] as List<dynamic>;
      final checking =
          accounts.singleWhere(
                (account) =>
                    (account as Map<String, dynamic>)['id'] == 'boa-checking',
              )
              as Map<String, dynamic>;

      expect(checking['name'], 'Bank of America Checking • 5080');
      expect(checking['display_name'], 'Bank of America Checking • 5080');
      expect(checking['display_detail'], 'Adv Plus Banking');
      expect(checking, isNot(contains('raw_name')));
      expect(checking, isNot(contains('official_name')));
      expect(checking['source'], 'plaid');
      expect(checking['source_label'], 'Plaid');
      expect(checking['plaid_connected'], isTrue);
      expect(checking['institution'], 'Bank of America');
      expect(checking['mask'], '5080');
      expect(checking['sync_status'], 'connected');
      expect(checking['current_balance'], 1234.56);
      expect(checking['available_balance'], 1100);
    },
  );

  test(
    'What did I spend this month uses Plaid transactions from Clarity',
    () async {
      final summary = await _buildPlaidTruthSummary();
      final cashFlow = summary['cash_flow'] as Map<String, dynamic>;
      final dataSources =
          summary['financial_data_sources'] as Map<String, dynamic>;
      final transactions = summary['transactions'] as List<dynamic>;
      final pending =
          transactions.singleWhere(
                (transaction) =>
                    (transaction as Map<String, dynamic>)['id'] ==
                    'plaid-pending',
              )
              as Map<String, dynamic>;

      expect(cashFlow['spent_this_month'], 12.34);
      expect(cashFlow['income_this_month'], 2500);
      expect(dataSources['primary_source'], 'plaid');
      expect(dataSources['plaid_accounts'], 1);
      expect(dataSources['plaid_transactions'], 3);
      expect(dataSources['pending_plaid_transactions'], 1);
      expect(pending['source'], 'plaid');
      expect(pending['source_label'], 'Plaid');
      expect(pending['pending'], isTrue);
    },
  );

  test(
    'What does Clarity know about my finances includes budget truth',
    () async {
      final summary = await _buildPlaidTruthSummary();
      final budget = summary['budget'] as Map<String, dynamic>;
      final budgetCategories = budget['categories'] as List<dynamic>;
      final coffee =
          budgetCategories.singleWhere(
                (category) =>
                    (category as Map<String, dynamic>)['category'] ==
                    'Coffee / Quick Food',
              )
              as Map<String, dynamic>;

      expect(budget['period_key'], '2026-06');
      expect(budget['total_budgeted'], 50);
      expect(budget['total_spent'], 12.34);
      expect(coffee['budgeted'], 50);
      expect(coffee['spent'], 12.34);
      expect(coffee['remaining'], 37.66);
      expect(coffee['on_track'], isTrue);
    },
  );
}

Future<Map<String, dynamic>> _buildPlaidTruthSummary() {
  final model = FinancialReadModel.fromRecords(
    accounts: [
      Account(
        id: 'boa-checking',
        name: 'Adv Plus Banking',
        type: AccountType.checking,
        institution: 'Bank of America',
        currentBalance: 1234.56,
        source: 'plaid',
        plaidItemId: 'item-redacted',
        plaidAccountId: 'account-redacted',
        syncStatus: 'connected',
        lastSyncedAt: DateTime.utc(2026, 6, 9, 13, 29),
        plaidInstitutionName: 'Bank of America',
        plaidAccountMask: '5080',
        plaidAvailableBalance: 1100,
        plaidOfficialName: 'Adv Plus Banking',
      ),
    ],
    categories: [
      _category(id: 'cat-coffee', name: 'Coffee / Quick Food'),
      _category(id: 'cat-income', name: 'Income / Payroll', type: 'income'),
      _category(id: 'cat-shopping', name: 'Shopping'),
    ],
    transactionRecords: [
      _record(
        id: 'plaid-coffee',
        accountId: 'boa-checking',
        date: DateTime(2026, 6, 5),
        categoryId: 'cat-coffee',
        amount: 12.34,
        type: 'expense',
        description: 'Coffee Shop',
        source: 'plaid',
        importedFromCsv: false,
      ),
      _record(
        id: 'plaid-payroll',
        accountId: 'boa-checking',
        date: DateTime(2026, 6, 1),
        categoryId: 'cat-income',
        amount: 2500,
        type: 'income',
        description: 'Payroll',
        source: 'plaid',
        importedFromCsv: false,
      ),
      _record(
        id: 'plaid-pending',
        accountId: 'boa-checking',
        date: DateTime(2026, 6, 8),
        categoryId: 'cat-shopping',
        amount: 99,
        type: 'expense',
        description: 'Pending Store',
        source: 'plaid',
        importedFromCsv: false,
        pending: true,
      ),
    ],
    budgets: [
      BudgetRecord(
        id: 'budget-coffee',
        userId: 'user',
        name: 'Coffee / Quick Food',
        categoryId: 'cat-coffee',
        categoryKey: normalizedCategoryKey('Coffee / Quick Food'),
        amount: 50,
        period: 'monthly',
        startDate: DateTime(2026, 6),
        createdAt: DateTime(2026, 6),
        updatedAt: DateTime(2026, 6),
      ),
    ],
  );
  final service = AssistantFinancialContextService(
    loadFinancialReadModel: () async => model,
    spendReference: () => DateTime(2026, 6, 9),
    notifyDataChanged: () {},
  );
  return service.buildSummary();
}

TransactionRecord _record({
  required String id,
  required DateTime date,
  required String categoryId,
  String accountId = 'checking',
  double amount = -10,
  String type = 'expense',
  String? description,
  bool importedFromCsv = true,
  String? importId = 'import',
  String source = 'csv',
  bool pending = false,
}) {
  return TransactionRecord(
    id: id,
    userId: 'user',
    accountId: accountId,
    categoryId: categoryId,
    amount: amount,
    type: type,
    description: description ?? 'Transaction $id',
    date: date,
    merchant: null,
    importedFromCsv: importedFromCsv,
    importId: importId,
    source: source,
    pending: pending,
    createdAt: date,
    updatedAt: date,
  );
}

CategoryRecord _category({
  required String id,
  required String name,
  String type = 'expense',
}) {
  final now = DateTime(2026, 6);
  return CategoryRecord(
    id: id,
    userId: 'user',
    name: name,
    normalizedName: normalizedCategoryKey(name),
    type: type,
    createdAt: now,
    updatedAt: now,
  );
}
