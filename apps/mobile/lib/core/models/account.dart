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
    this.plaidCreditLimit,
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
  final double? plaidCreditLimit;
  final String? plaidOfficialName;

  bool get isPlaidConnected => source == 'plaid' && plaidItemId != null;

  bool get isManualOrCsv => !isPlaidConnected;

  String get sourceLabel => isPlaidConnected ? 'Plaid' : 'Manual/CSV';

  String get displayName {
    if (!isPlaidConnected) return name;
    final institutionName =
        _cleanPlaidText(plaidInstitutionName) ?? _cleanPlaidText(institution);
    final baseName = institutionName != null
        ? '$institutionName ${type.displayLabel}'
        : _plaidProductName ?? type.displayLabel;
    return _withPlaidMask(baseName);
  }

  String get displaySubtitle {
    if (!isPlaidConnected) return _cleanPlaidText(institution) ?? '';
    final institutionName =
        _cleanPlaidText(plaidInstitutionName) ?? _cleanPlaidText(institution);
    final productName = institutionName == null ? null : _plaidProductName;
    return productName ?? '';
  }

  String _withPlaidMask(String value) {
    final mask = _cleanPlaidText(plaidAccountMask);
    if (mask == null) return value;
    return '$value • $mask';
  }

  String? get _plaidProductName {
    if (!isPlaidConnected) return _cleanPlaidText(name);
    final mask = _cleanPlaidText(plaidAccountMask);
    final candidates = [
      _cleanPlaidText(plaidOfficialName),
      _cleanPlaidText(name),
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (!_isGenericPlaidAccountName(candidate, type: type, mask: mask)) {
        return candidate;
      }
    }
    return null;
  }

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
    double? plaidCreditLimit,
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
      plaidCreditLimit: plaidCreditLimit ?? this.plaidCreditLimit,
      plaidOfficialName: plaidOfficialName ?? this.plaidOfficialName,
    );
  }
}

String? _cleanPlaidText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
}

bool _isGenericPlaidAccountName(
  String value, {
  required AccountType type,
  required String? mask,
}) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) return true;
  final typeLabel = type.displayLabel.toLowerCase();
  final genericNames = {
    'account',
    'plaid account',
    'depository',
    'depository account',
    'credit',
    'credit account',
    'checking',
    'checking account',
    'savings',
    'savings account',
    'credit card',
    'credit card account',
    typeLabel,
    '$typeLabel account',
  };
  if (genericNames.contains(normalized)) return true;
  if (normalized.startsWith('depository account') ||
      normalized.startsWith('credit account')) {
    return true;
  }
  if (mask != null && normalized.endsWith(' $mask')) {
    final withoutMask = normalized
        .substring(0, normalized.length - mask.length)
        .trim();
    return genericNames.contains(withoutMask);
  }
  return false;
}
