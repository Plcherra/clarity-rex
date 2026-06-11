import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/models/models.dart';
import '../../plaid/application/plaid_link_service.dart';
import '../data/connect_bank_entry_point_tracker.dart';
import '../data/plaid_account_service.dart';
import 'accounts_navigation_actions.dart';
import 'accounts_plaid_status_helpers.dart';
import 'widgets/accounts_app_bar.dart';
import 'widgets/accounts_body.dart';
import 'widgets/accounts_data_notifier.dart';

enum _AddAccountAction { connectBank, importCsv, manual }

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({
    super.key,
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

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late final AccountsDataNotifier _dataNotifier;
  var _refreshingAccounts = false;
  String? _accountNotice;
  var _plaidStatuses = <String, PlaidItemStatus>{};
  var _syncingPlaidItemIds = <String>{};

  AccountsNavigationActions get _navigation => AccountsNavigationActions(
    controller: widget.controller,
    dashboardController: widget.dashboardController,
    transactionController: widget.transactionController,
    budgetController: widget.budgetController,
    importJobStatusController: widget.importJobStatusController,
  );

  @override
  void initState() {
    super.initState();
    _dataNotifier = AccountsDataNotifier();
    widget.controller.addListener(_handleControllerChanged);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant AccountsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _loadData();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _dataNotifier.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    _dataNotifier.setLoading();
    try {
      final accounts = await widget.controller.accountOverviewItems;
      final statuses = await loadPlaidStatuses(widget.controller, accounts);
      if (!mounted) return;
      setState(() => _plaidStatuses = statuses);
      _dataNotifier.setData(accounts);
    } on Object catch (error) {
      if (!mounted) return;
      _dataNotifier.setError(error);
    }
  }

  Future<void> _connectBank(
    BuildContext context, {
    required String surface,
  }) async {
    trackConnectBankEntryPoint(
      surface: surface,
      action: ConnectBankEntryAction.connectBank,
    );
    try {
      final result = await widget.controller.connectBank();
      if (!context.mounted) return;
      final message = switch (result) {
        PlaidConnectionSuccess(:final institutionName, :final accountsSynced) =>
          'Bank connected successfully: ${institutionName ?? 'your bank'}'
              '${accountsSynced > 0 ? ' and synced $accountsSynced account${accountsSynced == 1 ? '' : 's'}' : ''}.',
        PlaidConnectionExit(:final errorCode) when errorCode != null =>
          'Bank connection stopped before it finished. You can try again. ($errorCode)',
        PlaidConnectionExit(:final status) when status != null =>
          'Bank connection stopped before it finished. Plaid status: $status.',
        PlaidConnectionExit() =>
          'Bank connection cancelled. No account was added.',
      };
      if (result is PlaidConnectionSuccess) {
        setState(() => _accountNotice = message);
        _refreshAfterPlaidConnection();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on PlaidLinkServiceException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open bank connection.')),
      );
    }
  }

  Future<void> _showAddAccountOptions(BuildContext context) async {
    final action = await showModalBottomSheet<_AddAccountAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add account',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect another bank with Plaid, or use manual tools when you need a fallback.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.account_balance_rounded),
                  title: const Text('Connect bank'),
                  subtitle: const Text('Use Plaid to add another bank.'),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(_AddAccountAction.connectBank),
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded),
                  title: const Text('Import CSV instead'),
                  subtitle: const Text('Create a manual account for bank files.'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_AddAccountAction.importCsv),
                ),
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('Add manual account'),
                  subtitle: const Text('Track an account without Plaid.'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_AddAccountAction.manual),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || action == null) return;

    final navigation = _navigation;
    switch (action) {
      case _AddAccountAction.connectBank:
        await _connectBank(context, surface: 'accounts_add');
        return;
      case _AddAccountAction.importCsv:
        await navigation.importCsvInstead(context, surface: 'accounts_add');
        return;
      case _AddAccountAction.manual:
        await navigation.addManualAccount(context, surface: 'accounts_add');
        return;
    }
  }

  Future<void> _refreshConnectedAccounts(BuildContext context) async {
    final itemIds = _connectedPlaidItemIds();
    if (itemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect a bank before refreshing.')),
      );
      return;
    }

    setState(() {
      _refreshingAccounts = true;
      _syncingPlaidItemIds = {..._syncingPlaidItemIds, ...itemIds};
    });
    try {
      final summaries = <PlaidSyncSummary>[];
      for (final itemId in itemIds) {
        summaries.add(await _resyncItem(itemId));
      }
      if (!context.mounted) return;
      final accountCount = summaries.fold<int>(
        0,
        (sum, item) => sum + item.accountsSynced,
      );
      final transactionCount = summaries.fold<int>(
        0,
        (sum, item) => sum + item.transactionsAdded + item.transactionsModified,
      );
      final message =
          'Accounts refreshed: $accountCount account${accountCount == 1 ? '' : 's'}, '
          '$transactionCount transaction update${transactionCount == 1 ? '' : 's'}.';
      setState(() => _accountNotice = message);
      _refreshAfterPlaidConnection();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on PlaidLinkServiceException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not refresh connected accounts.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshingAccounts = false;
          _syncingPlaidItemIds = _syncingPlaidItemIds.difference(itemIds);
        });
      }
    }
  }

  Future<void> _resyncPlaidItem(BuildContext context, String itemId) async {
    setState(() => _syncingPlaidItemIds = {..._syncingPlaidItemIds, itemId});
    try {
      final summary = await _resyncItem(itemId);
      if (!context.mounted) return;
      final updates = summary.transactionsAdded + summary.transactionsModified;
      final message =
          'Account refreshed: ${summary.accountsSynced} account${summary.accountsSynced == 1 ? '' : 's'}, '
          '$updates transaction update${updates == 1 ? '' : 's'}.';
      setState(() => _accountNotice = message);
      _refreshAfterPlaidConnection();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on PlaidAccountServiceException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not refresh this account.')),
      );
    } finally {
      if (mounted) {
        setState(
          () =>
              _syncingPlaidItemIds = {..._syncingPlaidItemIds}..remove(itemId),
        );
      }
    }
  }

  Future<PlaidSyncSummary> _resyncItem(String itemId) async {
    final summary = await widget.controller.refreshPlaidItem(itemId);
    try {
      final status = await widget.controller.plaidItemStatus(itemId);
      if (mounted) {
        setState(() => _plaidStatuses = {..._plaidStatuses, itemId: status});
      }
    } on Object {
      if (mounted) {
        setState(
          () => _plaidStatuses = {
            ..._plaidStatuses,
            itemId: PlaidItemStatus(
              itemId: itemId,
              status: PlaidAccountConnectionStatus.degraded,
            ),
          },
        );
      }
    }
    return summary;
  }

  void _refreshAfterPlaidConnection() {
    widget.controller.notifyChanged();
    widget.dashboardController.notifyChanged();
    widget.transactionController.notifyChanged();
    widget.budgetController.notifyChanged();
  }

  Set<String> _connectedPlaidItemIds() {
    final accounts = _dataNotifier.data;
    if (accounts == null) return const <String>{};
    return connectedPlaidItemIdsFrom(accounts);
  }

  PlaidAccountConnectionStatus _statusFor(Account account) {
    final itemId = account.plaidItemId;
    if (_syncingPlaidItemIds.contains(itemId)) {
      return PlaidAccountConnectionStatus.syncing;
    }
    return _plaidStatuses[itemId]?.status ??
        PlaidAccountConnectionStatus.connected;
  }

  DateTime? _lastSyncedAtFor(Account account) {
    final itemId = account.plaidItemId;
    if (!account.isPlaidConnected || itemId == null) return null;
    return _plaidStatuses[itemId]?.lastSyncedAt;
  }

  @override
  Widget build(BuildContext context) {
    final navigation = _navigation;
    return Scaffold(
      appBar: AccountsAppBar(
        refreshingAccounts: _refreshingAccounts,
        onRefreshAccounts: () => _refreshConnectedAccounts(context),
        onAddAccount: () => _showAddAccountOptions(context),
      ),
      body: AccountsBody(
        dataNotifier: _dataNotifier,
        accountNotice: _accountNotice,
        onDismissNotice: () => setState(() => _accountNotice = null),
        onConnectBank: () => _connectBank(context, surface: 'accounts_empty'),
        onImportCsvInstead: () =>
            navigation.importCsvInstead(context, surface: 'accounts_empty'),
        onAddManualAccount: () =>
            navigation.addManualAccount(context, surface: 'accounts_empty'),
        onRefreshAccounts: () => _refreshConnectedAccounts(context),
        onOpenAccountDetail: (account) =>
            navigation.openAccountDetail(context, account),
        onResyncPlaidItem: (itemId) => _resyncPlaidItem(context, itemId),
        statusFor: _statusFor,
        lastSyncedAtFor: _lastSyncedAtFor,
      ),
    );
  }
}
