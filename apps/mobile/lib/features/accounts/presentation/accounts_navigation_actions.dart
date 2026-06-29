import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/models/models.dart';
import '../data/connect_bank_entry_point_tracker.dart';
import 'account_detail_screen.dart';
import 'widgets/add_account_dialog.dart';

class AccountsNavigationActions {
  const AccountsNavigationActions({
    required this.controller,
    required this.dashboardController,
    required this.transactionController,
    required this.budgetController,
    required this.importJobStatusController,
  });

  final AccountUiController controller;
  final DashboardUiController dashboardController;
  final TransactionUiController transactionController;
  final BudgetUiController budgetController;
  final ImportJobStatusController importJobStatusController;

  Future<Account?> showAddAccountDialog(BuildContext context) async {
    return showDialog<Account>(
      context: context,
      builder: (dialogContext) => AddAccountDialog(
        onCreate: (name, type, institution, balance) async {
          final draft = Account(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: name,
            type: type,
            institution: institution,
            currentBalance: balance,
          );
          final created = await controller.addAccount(draft);
          if (!dialogContext.mounted) return null;
          if (created == null) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('Could not save account.')),
            );
            return null;
          }
          Navigator.of(dialogContext).pop(created);
          return created;
        },
      ),
    );
  }

  Future<void> openAccountDetail(
    BuildContext context,
    Account account, {
    bool promptCsvImport = false,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AccountDetailScreen(
          controller: controller,
          dashboardController: dashboardController,
          transactionController: transactionController,
          budgetController: budgetController,
          importJobStatusController: importJobStatusController,
          accountId: account.id,
          seedAccount: account,
          promptCsvImport: promptCsvImport,
        ),
      ),
    );
  }

  Future<void> importCsvInstead(
    BuildContext context, {
    String surface = 'accounts_empty',
  }) async {
    trackConnectBankEntryPoint(
      surface: surface,
      action: ConnectBankEntryAction.importCsvInstead,
    );
    final account = await showAddAccountDialog(context);
    if (!context.mounted || account == null) return;
    await openAccountDetail(context, account, promptCsvImport: true);
  }

  Future<void> addManualAccount(
    BuildContext context, {
    String surface = 'accounts_empty',
  }) async {
    trackConnectBankEntryPoint(
      surface: surface,
      action: ConnectBankEntryAction.addManualAccount,
    );
    await showAddAccountDialog(context);
  }
}
