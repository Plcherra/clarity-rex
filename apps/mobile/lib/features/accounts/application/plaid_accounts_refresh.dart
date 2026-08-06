import '../../../app/ui_dependencies.dart';
import '../../../l10n/app_localizations.dart';
import '../../plaid/application/plaid_connection_models.dart';
import '../presentation/accounts_plaid_status_helpers.dart';

/// Result of syncing one or more connected Plaid items from the UI.
class PlaidAccountsRefreshResult {
  const PlaidAccountsRefreshResult({
    required this.hadConnectedItems,
    required this.accountCount,
    required this.transactionUpdates,
    required this.anyRefreshUnavailable,
  });

  final bool hadConnectedItems;
  final int accountCount;
  final int transactionUpdates;
  final bool anyRefreshUnavailable;
}

/// Syncs connected Plaid items, optionally limited to one Clarity account.
Future<PlaidAccountsRefreshResult> refreshConnectedPlaidAccounts({
  required AccountUiController accounts,
  String? onlyAccountId,
}) async {
  final overview = await accounts.accountOverviewItems;
  final scoped = onlyAccountId == null
      ? overview
      : overview
            .where((item) => item.account.id == onlyAccountId)
            .toList(growable: false);
  final itemIds = connectedPlaidItemIdsFrom(scoped);
  if (itemIds.isEmpty) {
    return const PlaidAccountsRefreshResult(
      hadConnectedItems: false,
      accountCount: 0,
      transactionUpdates: 0,
      anyRefreshUnavailable: false,
    );
  }

  final summaries = <PlaidSyncSummary>[];
  for (final itemId in itemIds) {
    summaries.add(await accounts.refreshPlaidItem(itemId));
  }

  return PlaidAccountsRefreshResult(
    hadConnectedItems: true,
    accountCount: summaries.fold<int>(
      0,
      (sum, item) => sum + item.accountsSynced,
    ),
    transactionUpdates: summaries.fold<int>(
      0,
      (sum, item) => sum + item.transactionUpdates,
    ),
    anyRefreshUnavailable: summaries.any(
      (item) => item.transactionsRefreshUnavailable,
    ),
  );
}

/// User-facing snackbar copy for a connected-Plaid refresh.
String plaidAccountsRefreshMessage(
  AppLocalizations l10n,
  PlaidAccountsRefreshResult result,
) {
  if (!result.hadConnectedItems) {
    return l10n.accountsScreenNoActiveConnectionRefresh;
  }
  return buildPlaidRefreshMessage(
    l10n,
    accountCount: result.accountCount,
    transactionUpdates: result.transactionUpdates,
    anyRefreshUnavailable: result.anyRefreshUnavailable,
  );
}
