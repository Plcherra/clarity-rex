import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_service.dart';

final class AccountService {
  AccountService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  User get _currentUser {
    final user = _supabaseService.auth.currentUser;
    if (user == null) throw const SupabaseAuthRequiredException();
    return user;
  }

  Future<List<Account>> fetchAccounts() async {
    final user = _currentUser;
    try {
      final rows = await _supabaseService.client
          .from('accounts')
          .select()
          .eq('user_id', user.id)
          .order('created_at');
      final accounts = rows.map<Account>(_accountFromJson).toList();
      return await _mergePlaidMetadata(user.id, accounts);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'accounts',
        action: 'fetchAccounts',
        message: 'Could not fetch accounts.',
        cause: e,
      );
    }
  }

  Stream<List<Account>> watchAccounts() {
    final user = _currentUser;
    return _supabaseService.client
        .from('accounts')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .asyncMap(
          (rows) => _mergePlaidMetadata(
            user.id,
            rows.map<Account>(_accountFromJson).toList(),
          ),
        );
  }

  Future<Account> createAccount(Account account) async {
    final user = _currentUser;
    try {
      final row = await _supabaseService.client
          .from('accounts')
          .insert({
            'user_id': user.id,
            'name': account.name.trim(),
            'type': _accountTypeToDatabaseValue(account.type),
            'institution': _nullableTrimmed(account.institution),
            'balance': account.currentBalance ?? 0,
            'currency': 'USD',
            'is_active': true,
          })
          .select()
          .single();
      return _accountFromJson(row);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'accounts',
        action: 'createAccount',
        message: 'Could not create account.',
        cause: e,
      );
    }
  }

  Future<Account> updateAccount(Account account) async {
    final user = _currentUser;
    try {
      final row = await _supabaseService.client
          .from('accounts')
          .update({
            'name': account.name.trim(),
            'type': _accountTypeToDatabaseValue(account.type),
            'institution': _nullableTrimmed(account.institution),
            'balance': account.currentBalance ?? 0,
            'currency': 'USD',
            'is_active': true,
          })
          .eq('user_id', user.id)
          .eq('id', account.id)
          .select()
          .single();
      return _accountFromJson(row);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'accounts',
        action: 'updateAccount',
        message: 'Could not update account.',
        cause: e,
      );
    }
  }

  Future<void> deleteAccount(String id) async {
    final user = _currentUser;
    try {
      await _supabaseService.client
          .from('accounts')
          .delete()
          .eq('user_id', user.id)
          .eq('id', id);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'accounts',
        action: 'deleteAccount',
        message: 'Could not delete account.',
        cause: e,
      );
    }
  }

  Future<List<Account>> _mergePlaidMetadata(
    String userId,
    List<Account> accounts,
  ) async {
    final plaidAccountIds = [
      for (final account in accounts)
        if (account.isPlaidConnected) account.id,
    ];
    if (plaidAccountIds.isEmpty) return accounts;

    final rows = await _supabaseService.client
        .from('plaid_accounts')
        .select(
          'linked_account_id,institution_name,name,official_name,mask,current_balance,available_balance,credit_limit,status',
        )
        .eq('user_id', userId)
        .inFilter('linked_account_id', plaidAccountIds);
    final metadataByAccountId = {
      for (final row in rows)
        if (_nullableString(row, 'linked_account_id') != null)
          _nullableString(row, 'linked_account_id')!: row,
    };
    return [
      for (final account in accounts)
        if (metadataByAccountId[account.id] case final metadata?)
          account.copyWith(
            name: _nullableString(metadata, 'name') ?? account.name,
            plaidInstitutionName:
                _nullableString(metadata, 'institution_name') ??
                account.institution ??
                _nullableString(metadata, 'name'),
            plaidOfficialName: _nullableString(metadata, 'official_name'),
            plaidAccountMask: _nullableString(metadata, 'mask'),
            plaidAvailableBalance: _nullableMoney(
              metadata,
              'available_balance',
            ),
            plaidCreditLimit: _nullableMoney(metadata, 'credit_limit'),
            currentBalance:
                _nullableMoney(metadata, 'current_balance') ??
                account.currentBalance,
            syncStatus:
                _nullableString(metadata, 'status') ?? account.syncStatus,
          )
        else
          account,
    ];
  }
}

Account _accountFromJson(Map<String, dynamic> json) {
  return Account(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    type: _accountTypeFromDatabaseValue(_string(json, 'type')),
    institution: _nullableString(json, 'institution'),
    currentBalance: _money(json, 'balance'),
    source: _nullableString(json, 'source'),
    plaidItemId:
        _nullableString(json, 'plaid_item_record_id') ??
        _nullableString(json, 'plaid_item_id'),
    plaidAccountId: _nullableString(json, 'plaid_account_id'),
    syncStatus: _nullableString(json, 'sync_status'),
    lastSyncedAt: _nullableDateTime(json, 'last_synced_at'),
  );
}

String _accountTypeToDatabaseValue(AccountType type) {
  return switch (type) {
    AccountType.checking => 'checking',
    AccountType.savings => 'savings',
    AccountType.creditCard => 'credit_card',
  };
}

AccountType _accountTypeFromDatabaseValue(String value) {
  return switch (value.trim().toLowerCase()) {
    'savings' => AccountType.savings,
    'credit_card' || 'creditcard' || 'credit card' => AccountType.creditCard,
    _ => AccountType.checking,
  };
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  return value?.toString() ?? '';
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final string = value is String ? value : value.toString();
  final trimmed = string.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _nullableTrimmed(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

double _money(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double? _nullableMoney(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _nullableDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final string = value is String ? value : value.toString();
  return DateTime.tryParse(string)?.toLocal();
}
