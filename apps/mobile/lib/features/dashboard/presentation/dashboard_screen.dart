import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../domain/dashboard_insight_anchor.dart';
import '../domain/dashboard_snapshot.dart';
import 'financial_dashboard_view.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.transactionController,
    required this.budgetController,
    required this.importJobStatusController,
    required this.accountController,
    required this.onBankSyncCompleted,
    this.isRoot = false,
    this.onConnectBank,
    this.onImportCsvInstead,
    this.scrollToAnchor,
    this.onScrollToAnchorHandled,
  });

  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final BudgetUiController budgetController;
  final ImportJobStatusController importJobStatusController;
  final AccountUiController accountController;
  final VoidCallback onBankSyncCompleted;
  final bool isRoot;
  final VoidCallback? onConnectBank;
  final VoidCallback? onImportCsvInstead;
  final DashboardInsightAnchor? scrollToAnchor;
  final VoidCallback? onScrollToAnchorHandled;

  @override
  Widget build(BuildContext context) {
    return FinancialDashboardView(
      controller: controller,
      transactionController: transactionController,
      budgetController: budgetController,
      importJobStatusController: importJobStatusController,
      accountController: accountController,
      onBankSyncCompleted: onBankSyncCompleted,
      scope: const GlobalDashboardScope(),
      showBackButton: !isRoot,
      title: '',
      onConnectBank: onConnectBank,
      onImportCsvInstead: onImportCsvInstead,
      scrollToAnchor: scrollToAnchor,
      onScrollToAnchorHandled: onScrollToAnchorHandled,
    );
  }
}
