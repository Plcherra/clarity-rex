import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../../core/supabase/supabase_service.dart';

final class BudgetService {
  BudgetService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  User get _currentUser {
    final user = _supabaseService.auth.currentUser;
    if (user == null) throw const SupabaseAuthRequiredException();
    return user;
  }

  Future<List<BudgetRecord>> fetchBudgets() async {
    final user = _currentUser;
    try {
      final rows = await _supabaseService.client
          .from('budgets')
          .select()
          .eq('user_id', user.id)
          .order('created_at');
      return rows.map(BudgetRecord.fromJson).toList();
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'budgets',
        action: 'fetchBudgets',
        message: 'Could not fetch budgets.',
        cause: e,
      );
    }
  }

  Future<BudgetRecord> createBudget({
    required String name,
    String? categoryId,
    String? categoryKey,
    required double amount,
    required String period,
    DateTime? startDate,
  }) async {
    final user = _currentUser;
    try {
      final row = await _supabaseService.client
          .from('budgets')
          .insert({
            'user_id': user.id,
            'name': name,
            'category_id': ?categoryId,
            'category_key': ?categoryKey,
            'amount': amount,
            'period': period,
            'start_date': startDate?.toIso8601String().split('T').first,
          })
          .select()
          .single();
      return BudgetRecord.fromJson(row);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'budgets',
        action: 'createBudget',
        message: 'Could not create budget.',
        cause: e,
      );
    }
  }

  Future<BudgetRecord> updateBudget(
    String id, {
    String? name,
    String? categoryId,
    String? categoryKey,
    double? amount,
    String? period,
    DateTime? startDate,
  }) async {
    final user = _currentUser;
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (categoryId != null) payload['category_id'] = categoryId;
    if (categoryKey != null) payload['category_key'] = categoryKey;
    if (amount != null) payload['amount'] = amount;
    if (period != null) payload['period'] = period;
    if (startDate != null) {
      payload['start_date'] = startDate.toIso8601String().split('T').first;
    }
    if (payload.isEmpty) {
      throw const SupabaseDataException(
        table: 'budgets',
        action: 'updateBudget',
        message: 'At least one budget field is required.',
      );
    }

    try {
      final row = await _supabaseService.client
          .from('budgets')
          .update(payload)
          .eq('user_id', user.id)
          .eq('id', id)
          .select()
          .single();
      return BudgetRecord.fromJson(row);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'budgets',
        action: 'updateBudget',
        message: 'Could not update budget.',
        cause: e,
      );
    }
  }

  Future<void> updateBudgetsCategoryIdentity({
    required List<String> ids,
    required String categoryId,
    required String categoryKey,
    required String name,
  }) async {
    final user = _currentUser;
    final cleanedIds = ids.map((id) => id.trim()).where((id) => id.isNotEmpty);
    final uniqueIds = cleanedIds.toSet().toList();
    if (uniqueIds.isEmpty) return;

    try {
      await _supabaseService.client
          .from('budgets')
          .update({
            'category_id': categoryId,
            'category_key': categoryKey,
            'name': name,
          })
          .eq('user_id', user.id)
          .inFilter('id', uniqueIds);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'budgets',
        action: 'updateBudgetsCategoryIdentity',
        message: 'Could not update budget categories.',
        cause: e,
      );
    }
  }

  Future<void> deleteBudget(String id) async {
    final user = _currentUser;
    try {
      await _supabaseService.client
          .from('budgets')
          .delete()
          .eq('user_id', user.id)
          .eq('id', id);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'budgets',
        action: 'deleteBudget',
        message: 'Could not delete budget.',
        cause: e,
      );
    }
  }

  Stream<List<BudgetRecord>> watchBudgets() {
    final user = _currentUser;
    return _supabaseService.client
        .from('budgets')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .map((rows) => rows.map(BudgetRecord.fromJson).toList());
  }
}
