import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../domain/dashboard_snapshot.dart';
import 'financial_dashboard_view.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.transactionController,
    required this.budgetController,
    required this.importJobStatusController,
    this.isRoot = false,
  });

  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final BudgetUiController budgetController;
  final ImportJobStatusController importJobStatusController;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    return FinancialDashboardView(
      controller: controller,
      transactionController: transactionController,
      budgetController: budgetController,
      importJobStatusController: importJobStatusController,
      scope: const GlobalDashboardScope(),
      showBackButton: !isRoot,
      title: 'Overview',
      buildSnapshot: (controller, scope) => controller.buildSnapshot(scope),
    );
  }
}
