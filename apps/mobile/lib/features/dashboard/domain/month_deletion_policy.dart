import '../../transactions/domain/bank_statement_monthly.dart';

enum MonthDeletionBlockReason { empty, multipleAccounts, plaidSynced }

final class MonthDeletionPolicy {
  const MonthDeletionPolicy._({
    required this.accountId,
    required this.blockReason,
  });

  const MonthDeletionPolicy.allowed(String accountId)
    : this._(accountId: accountId, blockReason: null);

  const MonthDeletionPolicy.blocked(MonthDeletionBlockReason reason)
    : this._(accountId: null, blockReason: reason);

  final String? accountId;
  final MonthDeletionBlockReason? blockReason;

  bool get canDelete => accountId != null && blockReason == null;

  String? get protectionMessage {
    return switch (blockReason) {
      MonthDeletionBlockReason.plaidSynced =>
        'Plaid transactions sync from your bank. Use resync or disconnect instead of local deletion.',
      _ => null,
    };
  }
}

MonthDeletionPolicy monthDeletionPolicyForLines(List<BankStatementLine> lines) {
  if (lines.isEmpty) {
    return const MonthDeletionPolicy.blocked(MonthDeletionBlockReason.empty);
  }
  if (lines.any((line) => line.transaction.isPlaid)) {
    return const MonthDeletionPolicy.blocked(
      MonthDeletionBlockReason.plaidSynced,
    );
  }

  final accountIds = lines.map((line) => line.transaction.accountId).toSet();
  if (accountIds.length != 1) {
    return const MonthDeletionPolicy.blocked(
      MonthDeletionBlockReason.multipleAccounts,
    );
  }

  return MonthDeletionPolicy.allowed(accountIds.first);
}
