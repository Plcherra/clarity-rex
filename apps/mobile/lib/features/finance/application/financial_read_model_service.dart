import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../accounts/data/account_service.dart';
import '../../accounts/data/account_statement_import_service.dart';
import '../../budgets/data/budget_service.dart';
import '../../budgets/domain/budget_models.dart';
import '../../categories/application/category_read_model.dart';
import '../../categories/data/category_service.dart';
import '../../categories/domain/category_normalization.dart';
import '../../dashboard/domain/dashboard_snapshot.dart';
import '../../transactions/application/transaction_record_mapper.dart';
import '../../transactions/data/merchant_category_rule_service.dart';
import '../../transactions/data/transaction_service.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../../transactions/domain/spend_categories.dart';
import '../../transactions/domain/transaction_review.dart';
import '../../transactions/domain/transaction_resolution.dart';

part 'financial_read_model.dart';
part 'financial_read_model_helpers.dart';

final class FinancialReadModelService {
  FinancialReadModelService({
    required AccountService accountService,
    required TransactionService transactionService,
    required BudgetService budgetService,
    required CategoryService categoryService,
    required MerchantCategoryRuleService merchantCategoryRuleService,
    required AccountStatementImportService accountStatementImportService,
    required CategoryReadModel categoryReadModel,
  }) : _accountService = accountService,
       _transactionService = transactionService,
       _budgetService = budgetService,
       _categoryService = categoryService,
       _merchantCategoryRuleService = merchantCategoryRuleService,
       _accountStatementImportService = accountStatementImportService,
       _categoryReadModel = categoryReadModel;

  final AccountService _accountService;
  final TransactionService _transactionService;
  final BudgetService _budgetService;
  final CategoryService _categoryService;
  final MerchantCategoryRuleService _merchantCategoryRuleService;
  final AccountStatementImportService _accountStatementImportService;
  final CategoryReadModel _categoryReadModel;
  Future<FinancialReadModel>? _inFlightLoad;

  Future<FinancialReadModel> load() async {
    final existingLoad = _inFlightLoad;
    if (existingLoad != null) {
      return existingLoad;
    }
    final load = _loadFresh();
    _inFlightLoad = load;
    try {
      return await load;
    } finally {
      if (identical(_inFlightLoad, load)) {
        _inFlightLoad = null;
      }
    }
  }

  Future<FinancialReadModel> _loadFresh() async {
    final accountsFuture = _loadPart<List<Account>>(
      source: 'accounts',
      action: _accountService.fetchAccounts,
      fallback: const [],
    );
    final transactionsFuture = _loadPart<List<TransactionRecord>>(
      source: 'transactions',
      action: _transactionService.fetchTransactions,
      fallback: const [],
    );
    final budgetsFuture = _loadPart<List<BudgetRecord>>(
      source: 'budgets',
      action: _budgetService.fetchBudgets,
      fallback: const [],
    );
    final categoriesFuture = _loadPart<List<CategoryRecord>>(
      source: 'categories',
      action: _categoryService.fetchCategories,
      fallback: const [],
    );
    final merchantRulesFuture = _loadPart<List<MerchantCategoryRule>>(
      source: 'merchant_category_rules',
      action: _merchantCategoryRuleService.fetchRules,
      fallback: const [],
    );
    final statementImportsFuture = _loadPart<List<AccountStatementImport>>(
      source: 'account_statement_imports',
      action: _accountStatementImportService.fetchImports,
      fallback: const [],
    );

    final accounts = await accountsFuture;
    final records = await transactionsFuture;
    final budgets = await budgetsFuture;
    final categories = await categoriesFuture;
    final merchantCategoryRules = await merchantRulesFuture;
    final statementImports = await statementImportsFuture;
    final loadIssues = [
      ...accounts.issues,
      ...records.issues,
      ...budgets.issues,
      ...categories.issues,
      ...merchantCategoryRules.issues,
      ...statementImports.issues,
    ];

    return FinancialReadModel.fromRecords(
      accounts: accounts.value,
      transactionRecords: records.value,
      budgets: budgets.value,
      categories: categories.value,
      merchantCategoryRules: merchantCategoryRules.value,
      statementImports: statementImports.value,
      categoryDisplayRenamesLower: _categoryReadModel.categoryDisplayRenames,
      loadIssues: loadIssues,
    );
  }

  Future<_FinancialReadPart<T>> _loadPart<T>({
    required String source,
    required Future<T> Function() action,
    required T fallback,
  }) async {
    try {
      return _FinancialReadPart(value: await action());
    } on Object catch (error) {
      return _FinancialReadPart(
        value: fallback,
        issues: [
          FinancialReadModelLoadIssue(
            source: source,
            message: error.toString(),
          ),
        ],
      );
    }
  }
}

final class _FinancialReadPart<T> {
  const _FinancialReadPart({required this.value, this.issues = const []});

  final T value;
  final List<FinancialReadModelLoadIssue> issues;
}
