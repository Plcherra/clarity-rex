import '../../../app/ui_dependencies.dart';
import '../../../core/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../data/plaid_account_service.dart';

Future<Map<String, PlaidItemStatus>> loadPlaidStatuses(
  AccountUiController controller,
  List<AccountOverviewItem> accounts,
) async {
  final statuses = <String, PlaidItemStatus>{};
  for (final itemId in connectedPlaidItemIdsFrom(accounts)) {
    try {
      statuses[itemId] = await controller.plaidItemStatus(itemId);
    } on Object {
      statuses[itemId] = PlaidItemStatus(
        itemId: itemId,
        status: PlaidAccountConnectionStatus.degraded,
      );
    }
  }
  return statuses;
}

Set<String> connectedPlaidItemIdsFrom(List<AccountOverviewItem> accounts) {
  return {
    for (final item in accounts)
      if (item.account.isPlaidConnected) item.account.plaidItemId!,
  };
}

Map<String, PlaidItemStatus> knownPlaidStatusesForAccounts(
  Map<String, PlaidItemStatus> currentStatuses,
  List<AccountOverviewItem> accounts,
) {
  final connectedItemIds = connectedPlaidItemIdsFrom(accounts);
  return {
    for (final entry in currentStatuses.entries)
      if (connectedItemIds.contains(entry.key)) entry.key: entry.value,
  };
}

String plaidConnectionStatusLabel(
  AppLocalizations l10n,
  PlaidAccountConnectionStatus status,
) {
  return switch (status) {
    PlaidAccountConnectionStatus.connected => l10n.plaidAccountStatusConnected,
    PlaidAccountConnectionStatus.syncing => l10n.plaidAccountResyncTooltipSyncing,
    PlaidAccountConnectionStatus.degraded => l10n.plaidAccountStatusDegradedLabel,
    PlaidAccountConnectionStatus.loginRequired => l10n.plaidAccountStatusNeedsLogin,
    PlaidAccountConnectionStatus.pendingExpiration =>
      l10n.plaidAccountResyncTooltipExpiringSoon,
    PlaidAccountConnectionStatus.disconnected =>
      l10n.plaidAccountResyncTooltipDisconnected,
  };
}

String accountTypeLabel(AppLocalizations l10n, AccountType type) {
  return switch (type) {
    AccountType.checking => l10n.commonChecking,
    AccountType.savings => l10n.commonSavings,
    AccountType.creditCard => l10n.commonCard,
  };
}
