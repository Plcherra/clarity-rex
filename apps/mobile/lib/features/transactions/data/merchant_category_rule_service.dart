import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_service.dart';

final class MerchantCategoryRule {
  const MerchantCategoryRule({
    required this.id,
    required this.userId,
    required this.merchantKey,
    this.merchantDisplay,
    required this.aliases,
    required this.categoryId,
    required this.matchType,
    required this.confidence,
  });

  final String id;
  final String userId;
  final String merchantKey;
  final String? merchantDisplay;
  final List<String> aliases;
  final String categoryId;
  final String matchType;
  final double confidence;

  factory MerchantCategoryRule.fromJson(Map<String, dynamic> json) {
    final aliases = json['aliases'];
    return MerchantCategoryRule(
      id: _string(json, 'id'),
      userId: _string(json, 'user_id'),
      merchantKey: _string(json, 'merchant_key'),
      merchantDisplay: _nullableString(json, 'merchant_display'),
      aliases: aliases is List
          ? aliases.whereType<String>().toList(growable: false)
          : const [],
      categoryId: _string(json, 'category_id'),
      matchType: _string(json, 'match_type'),
      confidence: _number(json, 'confidence'),
    );
  }
}

final class MerchantCategoryRuleService {
  MerchantCategoryRuleService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  User get _currentUser {
    final user = _supabaseService.auth.currentUser;
    if (user == null) throw const SupabaseAuthRequiredException();
    return user;
  }

  Future<List<MerchantCategoryRule>> fetchRules() async {
    final user = _currentUser;
    try {
      final rows = await _supabaseService.client
          .from('merchant_category_rules')
          .select()
          .eq('user_id', user.id)
          .order('merchant_key');
      return rows.map(MerchantCategoryRule.fromJson).toList();
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'merchant_category_rules',
        action: 'fetchRules',
        message: 'Could not fetch merchant category rules.',
        cause: e,
      );
    }
  }

  Future<MerchantCategoryRule> upsertRule({
    required String merchantKey,
    String? merchantDisplay,
    required String categoryId,
    List<String> aliases = const [],
    String matchType = 'normalized_exact',
    double confidence = 1,
  }) async {
    final user = _currentUser;
    final key = merchantKey.trim().toLowerCase();
    final category = categoryId.trim();
    if (key.isEmpty || category.isEmpty) {
      throw const SupabaseDataException(
        table: 'merchant_category_rules',
        action: 'upsertRule',
        message: 'Merchant key and category are required.',
      );
    }

    try {
      final row = await _supabaseService.client
          .from('merchant_category_rules')
          .upsert({
            'user_id': user.id,
            'merchant_key': key,
            'merchant_display': _cleanMerchantDisplay(merchantDisplay),
            'aliases': _cleanAliases(aliases),
            'category_id': category,
            'match_type': matchType,
            'confidence': confidence,
          }, onConflict: 'user_id,merchant_key')
          .select()
          .single();
      return MerchantCategoryRule.fromJson(row);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'merchant_category_rules',
        action: 'upsertRule',
        message: 'Could not save merchant category rule.',
        cause: e,
      );
    }
  }
}

String? _cleanMerchantDisplay(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.length <= 160 ? trimmed : trimmed.substring(0, 160);
}

List<String> _cleanAliases(List<String> aliases) {
  final out = <String>{};
  for (final alias in aliases) {
    final key = alias.trim().toLowerCase();
    if (key.isNotEmpty) out.add(key);
  }
  return out.toList(growable: false);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Missing or invalid "$key".');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Invalid "$key".');
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Missing or invalid "$key".');
}
