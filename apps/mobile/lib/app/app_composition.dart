import '../core/supabase/supabase_repository.dart';
import '../core/supabase/supabase_service.dart';
import '../features/accounts/application/account_workflow_service.dart';
import '../features/accounts/data/account_service.dart';
import '../features/accounts/data/account_statement_import_service.dart';
import '../features/accounts/data/plaid_account_service.dart';
import '../features/budgets/application/budget_cleanup_service.dart';
import '../core/l10n/app_localizations_lookup.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_service.dart';
import '../features/budgets/application/budget_workflow_service.dart';
import '../features/budgets/data/budget_service.dart';
import '../features/categories/application/category_read_model.dart';
import '../features/categories/data/category_service.dart';
import '../features/dashboard/application/dashboard_spend_reference_controller.dart';
import '../features/finance/application/financial_read_model_service.dart';
import '../features/finance/data/financial_audit_service.dart';
import '../features/plaid/application/plaid_link_service.dart';
import '../features/profile/application/avatar_storage_service.dart';
import '../features/profile/application/locale_controller.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/profile/application/profile_service.dart';
import '../features/profile/application/theme_mode_controller.dart';
import '../features/transactions/application/category_workflow_service.dart';
import '../features/transactions/application/import_job_status_service.dart';
import '../features/transactions/application/transaction_workflow_service.dart';
import '../features/transactions/data/csv_import_service.dart';
import '../features/transactions/data/merchant_category_rule_service.dart';
import '../features/transactions/data/openai_proxy_client.dart';
import '../features/transactions/data/transaction_service.dart';
import 'app_notifications.dart';
import 'app_startup_service.dart';
import 'dashboard_refresh_coordinator.dart';
import 'ui_dependencies.dart';

final class AppComposition {
  AppComposition({
    SupabaseService? supabaseService,
    bool initialAuthenticated = false,
    ThemeModeController? themeModeController,
    LocaleController? localeController,
  }) : supabaseService = supabaseService ?? const SupabaseService(),
       _initialAuthenticated = initialAuthenticated,
       themeModeController = themeModeController ?? ThemeModeController(),
       localeController = localeController ?? LocaleController(),
       _ownsThemeModeController = themeModeController == null,
       _ownsLocaleController = localeController == null {
    this.localeController.addListener(_onLocaleChangedForCategoryLabels);
  }

  final SupabaseService supabaseService;
  final bool _initialAuthenticated;
  final bool _ownsThemeModeController;
  final bool _ownsLocaleController;

  late final SupabaseRepository supabaseRepository = SupabaseRepository(
    supabaseService: supabaseService,
  );

  // Supabase-backed table services. AppComposition no longer constructs
  // local storage category, merchant-memory, or transaction override services.
  late final TransactionService transactionService =
      supabaseRepository.transactions;
  late final MerchantCategoryRuleService merchantCategoryRuleService =
      supabaseRepository.merchantCategoryRules;
  late final CategoryService categoryService = supabaseRepository.categories;
  late final FinancialAuditService financialAuditService =
      supabaseRepository.financialAudit;

  // Synchronous UI category state derived from the Supabase categories table.
  // This preserves existing picker/controller APIs without local persistence.
  late final CategoryReadModel categoryReadModel = CategoryReadModel(
    categoryService: categoryService,
    localeController: localeController,
  );
  late final ProfileService profileService = supabaseRepository.profiles;
  late final BudgetService budgetService = supabaseRepository.budgets;
  late final BudgetCleanupService budgetCleanupService = BudgetCleanupService(
    budgetService: budgetService,
    categoryService: categoryService,
    transactionService: transactionService,
  );
  late final AccountService accountService = supabaseRepository.accounts;
  late final AccountStatementImportService accountStatementImportService =
      supabaseRepository.accountStatementImports;
  late final PlaidLinkService plaidLinkService = PlaidLinkService();
  late final PlaidAccountService plaidAccountService = PlaidAccountService();
  final DashboardSpendReferenceController spendReferenceController =
      DashboardSpendReferenceController();
  late final FinancialReadModelService financialReadModelService =
      FinancialReadModelService(
        accountService: accountService,
        transactionService: transactionService,
        budgetService: budgetService,
        categoryService: categoryService,
        merchantCategoryRuleService: merchantCategoryRuleService,
        accountStatementImportService: accountStatementImportService,
        categoryReadModel: categoryReadModel,
      );
  late final ImportJobStatusService importJobStatusService =
      ImportJobStatusService(
        l10n: () => lookupForLocale(localeController.locale),
      );
  final ThemeModeController themeModeController;
  final LocaleController localeController;

  late final AuthService authService = AuthService(
    supabaseService: supabaseService,
  );

  late final AuthController authController = AuthController(
    authService: authService,
    initialAuthenticated: _initialAuthenticated,
    l10n: () => lookupForLocale(localeController.locale),
  );

  late final AvatarStorageService avatarStorageService = AvatarStorageService(
    supabaseService: supabaseService,
  );

  late final ProfileController profileController = ProfileController(
    profileService: profileService,
    authService: authService,
    avatarStorage: avatarStorageService,
    localeController: localeController,
    syncAfterProfileChanged: () async {
      // No local profile or merchant-memory hydration remains after auth/profile
      // changes; scoped UI controllers only need to refresh their Supabase data.
      notifications.transactionDataChanged();
    },
  );

  late final AppNotifications notifications = AppNotifications(ui: ui);

  late final AccountWorkflowService accountWorkflowService =
      AccountWorkflowService(
        accountService: accountService,
        transactionService: transactionService,
        budgetCleanupService: budgetCleanupService,
        refreshAllState: dashboardRefreshCoordinator.refreshAllState,
        notifyAccountsChanged: () => notifications.accountsChanged(),
      );

  late final BudgetWorkflowService budgetWorkflowService =
      BudgetWorkflowService(
        budgetService: budgetService,
        categoryReadModel: categoryReadModel,
        notifyDashboardAndBudgetsChanged: () =>
            notifications.dashboardAndBudgetsChanged(),
        refreshAllState: dashboardRefreshCoordinator.refreshAllState,
      );

  late final AppStartupService startupService = AppStartupService(
    authService: authService,
    budgetService: budgetService,
    accountService: accountService,
    transactionService: transactionService,
    categoryService: categoryService,
    categoryReadModel: categoryReadModel,
    notifyDashboardAndBudgetsChanged: () =>
        notifications.dashboardAndBudgetsChanged(),
    notifyAccountsChanged: () => notifications.accountsChanged(),
    notifyTransactionDataChanged: () => notifications.transactionDataChanged(),
  );

  late final DashboardRefreshCoordinator dashboardRefreshCoordinator =
      DashboardRefreshCoordinator(
        financialReadModelService: financialReadModelService,
        notifyTransactionDataChanged: () =>
            notifications.transactionDataChanged(),
      );

  late final CategoryWorkflowService categoryWorkflowService =
      CategoryWorkflowService(
        categoryService: categoryService,
        categoryReadModel: categoryReadModel,
        transactionService: transactionService,
        budgetService: budgetService,
        merchantCategoryRuleService: merchantCategoryRuleService,
        financialAuditService: financialAuditService,
        accountService: accountService,
        profileService: profileService,
        refreshAllState: dashboardRefreshCoordinator.refreshAllState,
        notifyTransactionDataChanged: () =>
            notifications.transactionDataChanged(),
      );

  late final TransactionWorkflowService transactionWorkflowService =
      TransactionWorkflowService(
        transactionService: transactionService,
        csvImportService: csvImportService,
        spendReferenceController: spendReferenceController,
        importJobStatusService: importJobStatusService,
        financialAuditService: financialAuditService,
        deleteStatementImport: accountStatementImportService.deleteImport,
        refreshCategories: categoryReadModel.refresh,
        categoryNameForId: categoryReadModel.categoryNameForId,
        refreshAllState: dashboardRefreshCoordinator.refreshAllState,
        notifyTransactionDataChanged: () =>
            notifications.transactionDataChanged(),
        notifyImportJobStatusChanged: () =>
            notifications.importJobStatusChanged(),
      );

  late final AppUiDependencies ui = AppUiDependencies(
    AppUiControllerBindings(
      spendReferenceController: spendReferenceController,
      transactionService: transactionService,
      categoryService: categoryService,
      categoryWorkflowService: categoryWorkflowService,
      transactionWorkflowService: transactionWorkflowService,
      categoryReadModel: categoryReadModel,
      financialReadModelService: financialReadModelService,
      financialAuditService: financialAuditService,
      accountService: accountService,
      budgetService: budgetService,
      budgetWorkflowService: budgetWorkflowService,
      importJobStatusService: importJobStatusService,
      accountWorkflowService: accountWorkflowService,
      plaidLinkService: plaidLinkService,
      plaidAccountService: plaidAccountService,
      notifyImportJobStatusChanged: () =>
          notifications.importJobStatusChanged(),
    ),
  );

  late final OpenAiProxyClient openAiProxyClient = SupabaseOpenAiProxyClient(
    supabaseService: supabaseService,
  );

  late final CsvImportService csvImportService = CsvImportService(
    accountService: accountService,
    transactionService: transactionService,
    categoryService: categoryService,
    merchantCategoryRuleService: merchantCategoryRuleService,
    accountStatementImportService: accountStatementImportService,
    openAiClient: openAiProxyClient,
  );

  void _onLocaleChangedForCategoryLabels() {
    ui.notifyBudgets();
    ui.notifyDashboard();
  }

  void dispose() {
    localeController.removeListener(_onLocaleChangedForCategoryLabels);
    _tryDispose(() => startupService.dispose());
    _tryDispose(() => categoryReadModel.dispose());
    _tryDispose(() => ui.dispose());
    _tryDispose(() => authController.dispose());
    _tryDispose(() => profileController.dispose());
    if (_ownsThemeModeController) {
      _tryDispose(() => themeModeController.dispose());
    }
    if (_ownsLocaleController) {
      _tryDispose(() => localeController.dispose());
    }
  }
}

void _tryDispose(void Function() dispose) {
  try {
    dispose();
  } on Object {
    return;
  }
}
