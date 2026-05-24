import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_service.dart';

final class AccountStatementImport {
  const AccountStatementImport({
    required this.accountId,
    required this.importId,
    this.statementBalance,
    this.startDate,
    this.endDate,
    required this.transactionCount,
    required this.createdAt,
  });

  final String accountId;
  final String importId;
  final double? statementBalance;
  final DateTime? startDate;
  final DateTime? endDate;
  final int transactionCount;
  final DateTime createdAt;

  factory AccountStatementImport.fromJson(Map<String, dynamic> json) {
    return AccountStatementImport(
      accountId: _string(json, 'account_id'),
      importId: _string(json, 'import_id'),
      statementBalance: _nullableMoney(json, 'statement_balance'),
      startDate: _nullableDate(json, 'statement_start_date'),
      endDate: _nullableDate(json, 'statement_end_date'),
      transactionCount: _int(json, 'transaction_count'),
      createdAt: _dateTime(json, 'created_at'),
    );
  }
}

final class AccountStatementImportInput {
  const AccountStatementImportInput({
    required this.accountId,
    required this.importId,
    this.statementBalance,
    this.startDate,
    this.endDate,
    required this.transactionCount,
  });

  final String accountId;
  final String importId;
  final double? statementBalance;
  final DateTime? startDate;
  final DateTime? endDate;
  final int transactionCount;
}

final class AccountStatementImportService {
  AccountStatementImportService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  User get _currentUser {
    final user = _supabaseService.auth.currentUser;
    if (user == null) throw const SupabaseAuthRequiredException();
    return user;
  }

  Future<List<AccountStatementImport>> fetchImports() async {
    final user = _currentUser;
    try {
      final rows = await _supabaseService.client
          .from('account_statement_imports')
          .select()
          .eq('user_id', user.id)
          .order('created_at');
      return rows.map(AccountStatementImport.fromJson).toList();
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'account_statement_imports',
        action: 'fetchImports',
        message: 'Could not fetch statement imports.',
        cause: e,
      );
    }
  }

  Future<AccountStatementImport> upsertImport(
    AccountStatementImportInput input,
  ) async {
    final user = _currentUser;
    try {
      final row = await _supabaseService.client
          .from('account_statement_imports')
          .upsert({
            'user_id': user.id,
            'account_id': input.accountId,
            'import_id': input.importId,
            'statement_balance': input.statementBalance,
            'statement_start_date': _dateOnly(input.startDate),
            'statement_end_date': _dateOnly(input.endDate),
            'transaction_count': input.transactionCount,
          }, onConflict: 'user_id,account_id,import_id')
          .select()
          .single();
      return AccountStatementImport.fromJson(row);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'account_statement_imports',
        action: 'upsertImport',
        message: 'Could not save statement import.',
        cause: e,
      );
    }
  }

  Future<void> deleteImport({
    required String accountId,
    required String importId,
  }) async {
    final user = _currentUser;
    try {
      await _supabaseService.client
          .from('account_statement_imports')
          .delete()
          .eq('user_id', user.id)
          .eq('account_id', accountId)
          .eq('import_id', importId);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'account_statement_imports',
        action: 'deleteImport',
        message: 'Could not delete statement import.',
        cause: e,
      );
    }
  }
}

String? _dateOnly(DateTime? date) => date?.toIso8601String().split('T').first;

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  return value?.toString() ?? '';
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double? _nullableMoney(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _nullableDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime _dateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
