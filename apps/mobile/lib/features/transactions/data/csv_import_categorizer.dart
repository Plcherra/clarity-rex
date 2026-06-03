import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_records.dart';
import '../../categories/domain/category_normalization.dart';
import '../application/transaction_record_mapper.dart';
import '../domain/merchant_normalization.dart';
import '../domain/spend_categories.dart';
import 'merchant_category_rule_service.dart';
import 'openai_proxy_client.dart';

const int kCsvCategorizationRequestBatchSize = 100;
const int kCsvMaxConcurrentCategorizationRequests = 3;

final class CsvImportCategoryApplicationResult {
  const CsvImportCategoryApplicationResult({
    required this.fallbackCategoryCount,
    required this.updatedTransactionCount,
  });

  final int fallbackCategoryCount;
  final int updatedTransactionCount;
}

final class CsvImportCategorizationBatchResult {
  const CsvImportCategorizationBatchResult({
    required this.index,
    required this.suggestions,
    this.error,
  });

  final int index;
  final Map<String, String> suggestions;
  final Object? error;
}

final class CsvImportCategorizer {
  CsvImportCategorizer({
    required Future<List<CategoryRecord>> Function() fetchCategories,
    required Future<List<MerchantCategoryRule>> Function()
    fetchMerchantCategoryRules,
    required Future<CategoryRecord> Function({
      required String name,
      required String type,
      String? color,
      String? icon,
    })
    createCategory,
    required Future<void> Function({
      required List<String> ids,
      required String categoryId,
    })
    updateTransactionsCategory,
    required bool Function() isAiConfigured,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic> body)
    categorizeTransactions,
  }) : _fetchCategories = fetchCategories,
       _fetchMerchantCategoryRules = fetchMerchantCategoryRules,
       _createCategory = createCategory,
       _updateTransactionsCategory = updateTransactionsCategory,
       _isAiConfigured = isAiConfigured,
       _categorizeTransactions = categorizeTransactions;

  final Future<List<CategoryRecord>> Function() _fetchCategories;
  final Future<List<MerchantCategoryRule>> Function()
  _fetchMerchantCategoryRules;
  final Future<CategoryRecord> Function({
    required String name,
    required String type,
    String? color,
    String? icon,
  })
  _createCategory;
  final Future<void> Function({
    required List<String> ids,
    required String categoryId,
  })
  _updateTransactionsCategory;
  final bool Function() _isAiConfigured;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body)
  _categorizeTransactions;

  Future<Map<String, String>> suggestCategoriesForRecords(
    List<TransactionRecord> records,
  ) async {
    if (records.isEmpty) return const {};
    final suggestions = <String, String>{};
    final learned = await learnedCategoryNamesFor(records);
    suggestions.addAll(learned);
    final recordsNeedingAi = records
        .where((record) => !learned.containsKey(record.id))
        .toList(growable: false);
    if (recordsNeedingAi.isEmpty) return suggestions;
    final allowedCategoryNames = await allowedCategoryNamesForAi();
    final batches = chunkList(
      recordsNeedingAi,
      kCsvCategorizationRequestBatchSize,
    );
    for (var i = 0; i < batches.length; i += 1) {
      final result = await categorizeBatchWithFallback(
        i,
        batches[i],
        allowedCategoryNames,
      );
      suggestions.addAll(result.suggestions);
    }
    return suggestions;
  }

  Future<CsvImportCategorizationBatchResult> categorizeBatchWithFallback(
    int index,
    List<TransactionRecord> records,
    List<String> allowedCategories,
  ) async {
    try {
      return CsvImportCategorizationBatchResult(
        index: index,
        suggestions: await _categorizeInsertedRows(records, allowedCategories),
      );
    } on Object catch (error) {
      return CsvImportCategorizationBatchResult(
        index: index,
        suggestions: _fallbackCategoriesForRecords(records),
        error: error,
      );
    }
  }

  Future<CsvImportCategoryApplicationResult> applyCategories(
    List<TransactionRecord> insertedRecords,
    Map<String, String> suggestedCategoryByTransactionId,
  ) async {
    if (insertedRecords.isEmpty) {
      return const CsvImportCategoryApplicationResult(
        fallbackCategoryCount: 0,
        updatedTransactionCount: 0,
      );
    }
    final categoryNames = <String>{
      kUnknownCategoryName,
      kAutomaticFallbackCategoryName,
    };
    for (final record in insertedRecords) {
      categoryNames.add(
        _automaticCategoryName(suggestedCategoryByTransactionId[record.id]),
      );
    }
    final categoryIdByName = await ensureCategories(categoryNames);
    final unknownCategoryId =
        categoryIdByName[normalizedCategoryKey(kUnknownCategoryName)];
    if (unknownCategoryId == null || unknownCategoryId.trim().isEmpty) {
      throw StateError('Could not resolve the Unknown category.');
    }
    final idsByCategoryId = <String, List<String>>{};
    var fallbackCategoryCount = 0;
    for (final record in insertedRecords) {
      if (record.categoryId == null || record.categoryId!.trim().isEmpty) {
        throw StateError(
          'Inserted transaction is missing the Unknown fallback category.',
        );
      }
      final normalizedName = _automaticCategoryName(
        suggestedCategoryByTransactionId[record.id],
      );
      final normalizedCategory = normalizeCategoryName(normalizedName);
      final categoryId =
          categoryIdByName[normalizedCategory?.normalizedName] ??
          unknownCategoryId;
      if (categoryId == unknownCategoryId) {
        fallbackCategoryCount += 1;
      }
      if (record.categoryId == categoryId) continue;
      idsByCategoryId.putIfAbsent(categoryId, () => <String>[]).add(record.id);
    }
    for (final entry in idsByCategoryId.entries) {
      await _updateTransactionsCategory(
        ids: entry.value,
        categoryId: entry.key,
      );
    }
    return CsvImportCategoryApplicationResult(
      fallbackCategoryCount: fallbackCategoryCount,
      updatedTransactionCount: idsByCategoryId.values.fold<int>(
        0,
        (sum, ids) => sum + ids.length,
      ),
    );
  }

  int resolvedSuggestionCount(Map<String, String> suggestions) {
    var count = 0;
    for (final categoryName in suggestions.values) {
      if (!isUnresolvedCategoryLabel(categoryName)) count += 1;
    }
    return count;
  }

  Future<List<String>> allowedCategoryNamesForAi() async {
    final byKey = <String, String>{};

    void add(String name) {
      final normalized = normalizeCategoryName(name);
      if (normalized == null) return;
      byKey[normalized.normalizedName] = normalized.displayName;
    }

    for (final categoryName in kSelectableSpendCategories) {
      add(categoryName);
    }
    add(kUnknownCategoryName);

    final existing = await _fetchCategories();
    for (final category in existing) {
      add(category.name);
    }

    final names = byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<Map<String, String>> ensureCategories(
    Set<String> categoryNames,
  ) async {
    final existing = await _fetchCategories();
    final out = <String, String>{};
    for (final category in existing) {
      out[categoryRecordKey(
            name: category.name,
            normalizedName: category.normalizedName,
          )] =
          category.id;
      out[normalizedCategoryKey(category.name)] = category.id;
    }
    for (final rawName in categoryNames) {
      final normalized =
          normalizeCategoryName(rawName) ??
          normalizeCategoryName(kUnknownCategoryName);
      if (normalized == null) {
        throw StateError('Could not normalize the Unknown category.');
      }
      final key = normalized.normalizedName;
      if (out.containsKey(key)) continue;
      final created = await _createCategory(
        name: normalized.displayName,
        type: isIncomeCategoryLabel(normalized.displayName)
            ? 'income'
            : 'expense',
      );
      out[key] = created.id;
    }
    return out;
  }

  Future<String> ensureUnknownCategoryId() async {
    final categoryIdByName = await ensureCategories({kUnknownCategoryName});
    final unknownCategoryId =
        categoryIdByName[normalizedCategoryKey(kUnknownCategoryName)];
    if (unknownCategoryId == null || unknownCategoryId.trim().isEmpty) {
      throw StateError('Could not resolve the Unknown category.');
    }
    return unknownCategoryId;
  }

  Future<Map<String, String>> learnedCategoryNamesFor(
    List<TransactionRecord> records,
  ) async {
    final rules = await _fetchMerchantCategoryRules();
    if (rules.isEmpty || records.isEmpty) return const {};

    final categories = await _fetchCategories();
    final categoryNameById = {
      for (final category in categories) category.id: category.name,
    };
    final ruleNameByMerchantKey = <String, String>{};
    for (final rule in rules) {
      if (rule.disabled) continue;
      final categoryName = categoryNameById[rule.categoryId];
      if (categoryName == null) continue;
      final normalizedCategory = normalizeCategoryName(categoryName);
      if (normalizedCategory == null) continue;

      final keys = <String>{rule.merchantKey.trim().toLowerCase()};
      keys.addAll(rule.aliases.map((alias) => alias.trim().toLowerCase()));
      keys.removeWhere((key) => key.isEmpty);
      for (final key in keys) {
        ruleNameByMerchantKey[key] = normalizedCategory.displayName;
      }
    }
    if (ruleNameByMerchantKey.isEmpty) return const {};

    final out = <String, String>{};
    for (final record in records) {
      final merchantKey = merchantKeyLowerFromDescription(
        record.description ?? record.merchant ?? '',
      );
      if (merchantKey.isEmpty) continue;
      final categoryName = ruleNameByMerchantKey[merchantKey];
      if (categoryName == null) continue;
      out[record.id] = categoryName;
    }
    return out;
  }

  Future<Map<String, String>> _categorizeInsertedRows(
    List<TransactionRecord> records,
    List<String> allowedCategories,
  ) async {
    if (!_isAiConfigured()) {
      throw const OpenAiProxyUnavailableException();
    }
    final response = await _categorizeTransactions({
      'allowedCategories': allowedCategories,
      'transactions': [
        for (final record in records)
          {
            'key': record.id,
            'date': record.date.toIso8601String().split('T').first,
            'amount': signedTransactionAmountFromRecord(record),
            'description': record.description ?? record.merchant ?? '',
          },
      ],
    });
    final suggestions = _parseCategorizationResponse(response);
    final errors = response['errors'];
    if (errors is List && errors.isNotEmpty) {
      if (suggestions.isEmpty) {
        throw FormatException('AI categorization failed: ${errors.first}');
      }
      debugPrint(
        '[Clarity][CSV import] AI returned partial fallback warnings: '
        '${errors.first}',
      );
    }
    return suggestions;
  }

  Map<String, String> _parseCategorizationResponse(
    Map<String, dynamic> response,
  ) {
    final rawSuggestions = response['suggestions'];
    if (rawSuggestions is! List) {
      throw const FormatException(
        'AI categorization response missing suggestions.',
      );
    }
    final out = <String, String>{};
    final duplicateKeys = <String>{};
    for (final suggestion in rawSuggestions) {
      if (suggestion is! Map) continue;
      final key = suggestion['key'];
      final categoryName = suggestion['categoryName'];
      if (key is! String || key.trim().isEmpty) continue;
      final cleanedKey = key.trim();
      if (out.containsKey(cleanedKey)) {
        duplicateKeys.add(cleanedKey);
        out[cleanedKey] = kUnknownCategoryName;
        continue;
      }
      if (categoryName is! String || categoryName.trim().isEmpty) {
        out[cleanedKey] = kUnknownCategoryName;
        continue;
      }
      final normalized = normalizeCategoryName(categoryName);
      out[cleanedKey] = normalized?.displayName ?? kUnknownCategoryName;
    }
    for (final key in duplicateKeys) {
      out[key] = kUnknownCategoryName;
    }
    return out;
  }

  Map<String, String> _fallbackCategoriesForRecords(
    List<TransactionRecord> records,
  ) {
    return {
      for (final record in records)
        record.id: _fallbackCategoryForRecord(record),
    };
  }

  String _fallbackCategoryForRecord(TransactionRecord record) {
    final description = record.description ?? record.merchant ?? '';
    final suggested = suggestCategoryFromDescription(
      description,
      amount: record.amount,
    );
    if (suggested.trim().toLowerCase() == 'uncategorized') {
      return kAutomaticFallbackCategoryName;
    }
    return normalizeCategoryName(suggested)?.displayName ??
        kAutomaticFallbackCategoryName;
  }

  String _automaticCategoryName(String? rawName) {
    final name = rawName?.trim();
    if (name == null || name.isEmpty) return kAutomaticFallbackCategoryName;
    final normalized = normalizeCategoryName(name);
    final displayName = normalized?.displayName;
    if (displayName == null || isUnresolvedCategoryLabel(displayName)) {
      return kAutomaticFallbackCategoryName;
    }
    return displayName;
  }
}

List<List<T>> chunkList<T>(List<T> items, int size) {
  final out = <List<T>>[];
  for (var i = 0; i < items.length; i += size) {
    final end = i + size > items.length ? items.length : i + size;
    out.add(items.sublist(i, end));
  }
  return out;
}
