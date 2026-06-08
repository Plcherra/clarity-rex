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
    required this.accountsSynced,
    required this.transactionsAdded,
    required this.transactionsModified,
    required this.transactionsRemoved,
  });

  final String itemId;
  final String status;
  final String? institutionName;
  final int accountsSynced;
  final int transactionsAdded;
  final int transactionsModified;
  final int transactionsRemoved;
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
  });

  final String itemId;
  final int accountsSynced;
  final int transactionsAdded;
  final int transactionsModified;
  final int transactionsRemoved;
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
