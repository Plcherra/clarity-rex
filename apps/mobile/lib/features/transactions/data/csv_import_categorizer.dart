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

final class CsvImportCategoryApplicationException implements Exception {
  CsvImportCategoryApplicationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class CsvImportCategoryApplicationResult {
  const CsvImportCategoryApplicationResult({
    required this.miscellaneousCategoryCount,
    required this.updatedTransactionCount,
  });

  final int miscellaneousCategoryCount;
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
    required Future<void> Function({
      required String merchantKey,
      String? merchantDisplay,
      required String categoryId,
    })
    upsertMerchantCategoryRule,
  }) : _fetchCategories = fetchCategories,
       _fetchMerchantCategoryRules = fetchMerchantCategoryRules,
       _createCategory = createCategory,
       _updateTransactionsCategory = updateTransactionsCategory,
       _isAiConfigured = isAiConfigured,
       _categorizeTransactions = categorizeTransactions,
       _upsertMerchantCategoryRule = upsertMerchantCategoryRule;

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
  final Future<void> Function({
    required String merchantKey,
    String? merchantDisplay,
    required String categoryId,
  })
  _upsertMerchantCategoryRule;

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
    if (recordsNeedingAi.isNotEmpty) {
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
    }
    return _completeSuggestions(records, suggestions);
  }

  Future<CsvImportCategorizationBatchResult> categorizeBatchWithFallback(
    int index,
    List<TransactionRecord> records,
    List<String> allowedCategories,
  ) async {
    try {
      final suggestions = await _categorizeInsertedRows(
        records,
        allowedCategories,
      );
      return CsvImportCategorizationBatchResult(
        index: index,
        suggestions: _completeSuggestions(records, suggestions),
      );
    } on Object catch (error) {
      return CsvImportCategorizationBatchResult(
        index: index,
        suggestions: _completeSuggestions(
          records,
          _fallbackCategoriesForRecords(records),
        ),
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
        miscellaneousCategoryCount: 0,
        updatedTransactionCount: 0,
      );
    }

    final suggestions = _completeSuggestions(
      insertedRecords,
      suggestedCategoryByTransactionId,
    );
    final categoryNames = <String>{};
    for (final record in insertedRecords) {
      categoryNames.add(_resolvedCategoryName(record, suggestions[record.id]));
    }
    final categoryIdByName = await ensureCategories(categoryNames);

    final idsByCategoryId = <String, List<String>>{};
    var miscellaneousCategoryCount = 0;
    for (final record in insertedRecords) {
      final categoryName = _resolvedCategoryName(
        record,
        suggestions[record.id],
      );
      final normalized = normalizeCategoryName(categoryName);
      if (normalized == null || isUnresolvedCategoryLabel(normalized.displayName)) {
        throw CsvImportCategoryApplicationException(
          'Could not resolve a category for imported transaction ${record.id}.',
        );
      }
      final categoryId = _requireCategoryId(
        categoryIdByName,
        normalized.displayName,
      );
      if (_isGenericBestEffortCategory(record, normalized.displayName)) {
        miscellaneousCategoryCount += 1;
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

    await _learnMerchantRulesFromAssignments(
      insertedRecords,
      suggestions,
      categoryIdByName,
    );

    return CsvImportCategoryApplicationResult(
      miscellaneousCategoryCount: miscellaneousCategoryCount,
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
      if (isUnresolvedCategoryLabel(normalized.displayName)) return;
      byKey[normalized.normalizedName] = normalized.displayName;
    }

    for (final categoryName in kSelectableSpendCategories) {
      if (isCatchAllCategoryLabel(categoryName)) continue;
      add(categoryName);
    }

    final existing = await _fetchCategories();
    for (final category in existing) {
      if (isCatchAllCategoryLabel(category.name)) continue;
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
      final normalized = normalizeCategoryName(rawName);
      if (normalized == null ||
          isUnresolvedCategoryLabel(normalized.displayName)) {
        continue;
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

  Future<String> ensureFallbackCategoryId() async {
    final categoryIdByName = await ensureCategories({
      kBestEffortExpenseCategoryName,
    });
    return _requireCategoryId(
      categoryIdByName,
      kBestEffortExpenseCategoryName,
    );
  }

  Future<Set<String>> legacyUncategorizedCategoryIds() async {
    final categories = await _fetchCategories();
    return {
      for (final category in categories)
        if (isUnresolvedCategoryLabel(category.name) ||
            isCatchAllCategoryLabel(category.name))
          category.id,
    };
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
      if (normalizedCategory == null ||
          isUnresolvedCategoryLabel(normalizedCategory.displayName) ||
          isCatchAllCategoryLabel(normalizedCategory.displayName)) {
        continue;
      }

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
    return _completeSuggestions(records, suggestions);
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
        continue;
      }
      out[cleanedKey] = _resolvedCategoryName(
        null,
        categoryName is String ? categoryName : null,
      );
    }
    for (final key in duplicateKeys) {
      out.remove(key);
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

  Map<String, String> _completeSuggestions(
    List<TransactionRecord> records,
    Map<String, String> suggestions,
  ) {
    final out = Map<String, String>.from(suggestions);
    for (final record in records) {
      out[record.id] = _resolvedCategoryName(record, out[record.id]);
    }
    return out;
  }

  String _fallbackCategoryForRecord(TransactionRecord record) {
    final description = record.description ?? record.merchant ?? '';
    final signedAmount = signedTransactionAmountFromRecord(record);
    return suggestCategoryFromDescription(
      description,
      amount: signedAmount,
    );
  }

  String _resolvedCategoryName(
    TransactionRecord? record,
    String? rawName,
  ) {
    if (record != null) {
      return _resolvedCategoryNameForRecord(
        record,
        rawName,
        signedTransactionAmountFromRecord(record),
      );
    }
    final name = rawName?.trim();
    if (name == null || name.isEmpty) {
      return kBestEffortExpenseCategoryName;
    }
    final normalized = normalizeCategoryName(name);
    final displayName = normalized?.displayName;
    if (displayName == null ||
        isUnresolvedCategoryLabel(displayName) ||
        isCatchAllCategoryLabel(displayName)) {
      return kBestEffortExpenseCategoryName;
    }
    return displayName;
  }

  String _resolvedCategoryNameForRecord(
    TransactionRecord record,
    String? rawName,
    double signedAmount,
  ) {
    final name = rawName?.trim();
    if (name == null || name.isEmpty) {
      return _fallbackCategoryForRecord(record);
    }
    final normalized = normalizeCategoryName(name);
    final displayName = normalized?.displayName;
    if (displayName == null ||
        isUnresolvedCategoryLabel(displayName) ||
        isCatchAllCategoryLabel(displayName)) {
      return _fallbackCategoryForRecord(record);
    }
    if (signedAmount < 0 && isIncomeCategoryLabel(displayName)) {
      return _fallbackCategoryForRecord(record);
    }
    return displayName;
  }

  bool _isGenericBestEffortCategory(
    TransactionRecord record,
    String categoryName,
  ) {
    final signedAmount = signedTransactionAmountFromRecord(record);
    return categoryName == bestEffortCategoryName(amount: signedAmount);
  }

  Future<void> _learnMerchantRulesFromAssignments(
    List<TransactionRecord> records,
    Map<String, String> suggestions,
    Map<String, String> categoryIdByName,
  ) async {
    final learnedByMerchantKey = <String, ({String categoryId, String? display})>{};
    for (final record in records) {
      final merchantKey = merchantKeyLowerFromDescription(
        record.description ?? record.merchant ?? '',
      );
      if (merchantKey.isEmpty) continue;
      final categoryName = _resolvedCategoryName(record, suggestions[record.id]);
      if (isCatchAllCategoryLabel(categoryName)) continue;
      final categoryId = categoryIdByName[normalizedCategoryKey(categoryName)];
      if (categoryId == null || categoryId.isEmpty) continue;
      learnedByMerchantKey[merchantKey] = (
        categoryId: categoryId,
        display: record.description ?? record.merchant,
      );
    }
    for (final entry in learnedByMerchantKey.entries) {
      await _upsertMerchantCategoryRule(
        merchantKey: entry.key,
        merchantDisplay: entry.value.display,
        categoryId: entry.value.categoryId,
      );
    }
  }

  String _requireCategoryId(
    Map<String, String> categoryIdByName,
    String categoryName,
  ) {
    final categoryId =
        categoryIdByName[normalizedCategoryKey(categoryName)]?.trim();
    if (categoryId == null || categoryId.isEmpty) {
      throw StateError('Could not resolve category id for $categoryName.');
    }
    return categoryId;
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
