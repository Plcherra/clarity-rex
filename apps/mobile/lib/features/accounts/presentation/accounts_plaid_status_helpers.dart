import '../../../app/ui_dependencies.dart';
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
