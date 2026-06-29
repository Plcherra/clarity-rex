import 'package:clarity/l10n/app_localizations.dart';

final class PlaidLinkServiceException implements Exception {
  const PlaidLinkServiceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class PlaidLinkToken {
  const PlaidLinkToken({required this.value, this.expiration});

  final String value;
  final String? expiration;
}

sealed class PlaidLinkLaunchResult {
  const PlaidLinkLaunchResult();
}

final class PlaidLinkLaunchSuccess extends PlaidLinkLaunchResult {
  const PlaidLinkLaunchSuccess({
    required this.publicToken,
    this.institutionId,
    this.institutionName,
    required this.accountCount,
  });

  final String publicToken;
  final String? institutionId;
  final String? institutionName;
  final int accountCount;
}

final class PlaidLinkLaunchExit extends PlaidLinkLaunchResult {
  const PlaidLinkLaunchExit({
    this.status,
    this.errorCode,
    this.errorType,
    this.requestId,
  });

  final String? status;
  final String? errorCode;
  final String? errorType;
  final String? requestId;
}

sealed class PlaidConnectionResult {
  const PlaidConnectionResult();
}

final class PlaidConnectionSuccess extends PlaidConnectionResult {
  const PlaidConnectionSuccess({
    required this.itemId,
    required this.status,
    this.institutionName,
    this.accounts = const [],
    required this.accountsSynced,
    required this.transactionsAdded,
    required this.transactionsModified,
    required this.transactionsRemoved,
  });

  final String itemId;
  final String status;
  final String? institutionName;
  final List<PlaidConnectedAccountSummary> accounts;
  final int accountsSynced;
  final int transactionsAdded;
  final int transactionsModified;
  final int transactionsRemoved;
}

final class PlaidConnectedAccountSummary {
  const PlaidConnectedAccountSummary({
    required this.linkedAccountId,
    required this.itemId,
    this.institutionName,
    required this.name,
    this.officialName,
    this.mask,
    this.accountType,
    this.accountSubtype,
    required this.status,
    this.currentBalance,
    this.availableBalance,
    this.isoCurrencyCode,
  });

  final String linkedAccountId;
  final String itemId;
  final String? institutionName;
  final String name;
  final String? officialName;
  final String? mask;
  final String? accountType;
  final String? accountSubtype;
  final String status;
  final double? currentBalance;
  final double? availableBalance;
  final String? isoCurrencyCode;
}

final class PlaidConnectionExit extends PlaidConnectionResult {
  const PlaidConnectionExit({
    this.status,
    this.errorCode,
    this.errorType,
    this.requestId,
  });

  final String? status;
  final String? errorCode;
  final String? errorType;
  final String? requestId;
}

final class PlaidSyncSummary {
  const PlaidSyncSummary({
    required this.itemId,
    required this.accountsSynced,
    required this.transactionsAdded,
    required this.transactionsModified,
    required this.transactionsRemoved,
    this.balancesRefreshed = false,
    this.transactionsRefreshStatus = 'skipped',
  });

  final String itemId;
  final int accountsSynced;
  final int transactionsAdded;
  final int transactionsModified;
  final int transactionsRemoved;
  final bool balancesRefreshed;
  final String transactionsRefreshStatus;

  int get transactionUpdates => transactionsAdded + transactionsModified;

  bool get transactionsRefreshUnavailable =>
      transactionsRefreshStatus == 'unavailable';
}

String buildPlaidRefreshMessage(
  AppLocalizations l10n, {
  required int accountCount,
  required int transactionUpdates,
  required bool anyRefreshUnavailable,
}) {
  final accountLabel = l10n.plaidRefreshAccountLabel(accountCount);
  if (transactionUpdates > 0) {
    return l10n.plaidRefreshWithTransactionUpdates(
      accountLabel,
      transactionUpdates,
    );
  }
  if (anyRefreshUnavailable) {
    return l10n.plaidRefreshBalancesOnlyUnavailable(accountLabel);
  }
  return l10n.plaidRefreshBalancesOnly(accountLabel);
}

abstract interface class PlaidLinkTokenApi {
  Future<PlaidLinkToken> createLinkToken();
}

abstract interface class PlaidPublicTokenExchangeApi {
  Future<PlaidConnectionSuccess> exchangePublicToken(
    PlaidLinkLaunchSuccess success,
  );
}

abstract interface class PlaidLinkLauncher {
  Future<PlaidLinkLaunchResult> open(PlaidLinkToken token);
}
