enum AccountType { checking, savings, creditCard }

extension AccountTypeDisplay on AccountType {
  String get displayLabel => switch (this) {
    AccountType.checking => 'Checking',
    AccountType.savings => 'Savings',
    AccountType.creditCard => 'Credit Card',
  };
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.institution,
    this.currentBalance,
    this.source,
    this.plaidItemId,
    this.plaidAccountId,
    this.syncStatus,
    this.lastSyncedAt,
    this.plaidInstitutionName,
    this.plaidAccountMask,
    this.plaidAvailableBalance,
    this.plaidOfficialName,
  });

  final String id;
  final String name;
  final AccountType type;
  final String? institution;

  /// Optional running balance for the account (not required for CSV import v1).
  final double? currentBalance;
  final String? source;
  final String? plaidItemId;
  final String? plaidAccountId;
  final String? syncStatus;
  final DateTime? lastSyncedAt;
  final String? plaidInstitutionName;
  final String? plaidAccountMask;
  final double? plaidAvailableBalance;
  final String? plaidOfficialName;

  bool get isPlaidConnected => source == 'plaid' && plaidItemId != null;

  bool get isManualOrCsv => !isPlaidConnected;

  String get sourceLabel => isPlaidConnected ? 'Plaid' : 'Manual/CSV';

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? institution,
    double? currentBalance,
    String? source,
    String? plaidItemId,
    String? plaidAccountId,
    String? syncStatus,
    DateTime? lastSyncedAt,
    String? plaidInstitutionName,
    String? plaidAccountMask,
    double? plaidAvailableBalance,
    String? plaidOfficialName,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      institution: institution ?? this.institution,
      currentBalance: currentBalance ?? this.currentBalance,
      source: source ?? this.source,
      plaidItemId: plaidItemId ?? this.plaidItemId,
      plaidAccountId: plaidAccountId ?? this.plaidAccountId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      plaidInstitutionName: plaidInstitutionName ?? this.plaidInstitutionName,
      plaidAccountMask: plaidAccountMask ?? this.plaidAccountMask,
      plaidAvailableBalance:
          plaidAvailableBalance ?? this.plaidAvailableBalance,
      plaidOfficialName: plaidOfficialName ?? this.plaidOfficialName,
    );
  }
}
