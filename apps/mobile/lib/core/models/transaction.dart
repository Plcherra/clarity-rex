enum FinancialRole {
  expense,
  income,
  transfer,
  creditCardPayment,
  refund,
  adjustment,
}

FinancialRole? financialRoleFromStorageValue(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'expense' => FinancialRole.expense,
    'income' => FinancialRole.income,
    'transfer' => FinancialRole.transfer,
    'credit_card_payment' ||
    'creditcardpayment' ||
    'credit card payment' => FinancialRole.creditCardPayment,
    'refund' => FinancialRole.refund,
    'adjustment' => FinancialRole.adjustment,
    _ => null,
  };
}

String financialRoleToStorageValue(FinancialRole role) {
  return switch (role) {
    FinancialRole.expense => 'expense',
    FinancialRole.income => 'income',
    FinancialRole.transfer => 'transfer',
    FinancialRole.creditCardPayment => 'credit_card_payment',
    FinancialRole.refund => 'refund',
    FinancialRole.adjustment => 'adjustment',
  };
}

class Transaction {
  const Transaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.accountId,
    this.category,
    this.balanceAfter,
    this.categoryLabel,
    this.importId,
    this.fingerprint,
    this.financialRole,
    this.source,
  });

  /// Parsed calendar date in local terms (time set to noon to avoid DST edge cases).
  final DateTime date;
  final String description;

  /// Signed: negative = money out (spend), positive = money in.
  final double amount;
  final String? category;
  final double? balanceAfter;

  /// Set after CSV parsing; parser rows use an empty id before account assignment.
  final String accountId;

  /// App-facing user category label resolved from the raw Supabase category id.
  final String? categoryLabel;

  /// Import batch identifier (helps debug and undo imports; v1 may be timestamp-based).
  final String? importId;

  /// Stable-ish fingerprint for dedupe within an account.
  final String? fingerprint;

  /// Optional stored role; when null, role is derived from heuristics + matcher.
  final FinancialRole? financialRole;

  /// Persistence source such as `plaid`, `csv`, or `manual`.
  final String? source;

  bool get isOutflow => amount < 0;

  bool get isPlaid => source?.trim().toLowerCase() == 'plaid';

  bool get isManualCsv {
    final normalized = source?.trim().toLowerCase();
    return normalized == 'csv' ||
        importId != null && importId!.trim().isNotEmpty;
  }

  String get sourceLabel => isPlaid ? 'Plaid' : 'Manual/CSV';
}
