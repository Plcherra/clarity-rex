import 'dart:convert';

/// Keep mobile finance packs under the rex-api ChatRequest size cap.
const int kAssistantFinancialContextMaxChars = 32000;

/// Progressively strip heavy optional sections until the JSON fits the API cap.
Map<String, dynamic> capAssistantFinancialContextSize(
  Map<String, dynamic> context, {
  int maxChars = kAssistantFinancialContextMaxChars,
}) {
  if (_encodedLength(context) <= maxChars) {
    return context;
  }

  var capped = Map<String, dynamic>.from(context);
  capped = _dropKey(capped, 'transaction_slices');
  if (_encodedLength(capped) <= maxChars) {
    return _markTruncated(capped, reason: 'dropped_transaction_slices');
  }

  capped = _shrinkList(capped, 'transactions', keep: 40);
  capped = _shrinkList(capped, 'matched_transactions', keep: 20);
  if (_encodedLength(capped) <= maxChars) {
    return _markTruncated(capped, reason: 'shrunk_transaction_lists');
  }

  capped = _dropKey(capped, 'category_spend_this_month');
  capped = _shrinkList(capped, 'transactions', keep: 20);
  capped = _shrinkList(capped, 'matched_transactions', keep: 10);
  if (_encodedLength(capped) <= maxChars) {
    return _markTruncated(capped, reason: 'dropped_category_spend');
  }

  capped = _dropKey(capped, 'statement_imports');
  capped = _dropKey(capped, 'biggest_month_over_month_increases');
  capped = _shrinkList(capped, 'categories', keep: 30);
  capped = _shrinkList(capped, 'budgets', keep: 20);
  capped = _shrinkList(capped, 'transactions', keep: 10);
  capped = _shrinkList(capped, 'matched_transactions', keep: 5);
  if (_encodedLength(capped) <= maxChars) {
    return _markTruncated(capped, reason: 'aggressive_shrink');
  }

  // Last resort: summary-only pack so chat never 500s on size.
  return _markTruncated(
    {
      'schema': capped['schema'],
      'generated_at': capped['generated_at'],
      'locale': capped['locale'],
      'data_status': capped['data_status'],
      'load_errors': capped['load_errors'],
      'freshness': capped['freshness'],
      'integration': {
        'mode': 'unified_clarity_rex',
        'full_financial_context_included': false,
        'raw_transactions_included': false,
        'transaction_detail_mode': 'summary_only_size_capped',
        'account_names_included': true,
        'merchant_names_included': false,
        'assistant_can_reference_specific_records': false,
        'default_context_is_summary_first': true,
        'drilldown_indexes_included': false,
        'size_capped': true,
      },
      'retrieval': {
        'default_transaction_limit': 0,
        'default_selection': 'summary_only_size_capped',
        'drilldown_policy':
            'Financial context was truncated to fit the API size limit. Use accounts, cash_flow, and budget only; do not invent transaction-level detail.',
        'supported_drilldown_filters': const <String>[],
      },
      'available_controls': capped['available_controls'],
      'period': capped['period'],
      'cash_flow': capped['cash_flow'],
      'financial_data_sources': capped['financial_data_sources'],
      'accounts': capped['accounts'] ?? const <Map<String, dynamic>>[],
      'top_spending_categories': capped['top_spending_categories'],
      'budget': capped['budget'],
      'transactions': const <Map<String, dynamic>>[],
    },
    reason: 'summary_only',
  );
}

int _encodedLength(Map<String, dynamic> context) {
  return jsonEncode(context).length;
}

Map<String, dynamic> _dropKey(Map<String, dynamic> context, String key) {
  if (!context.containsKey(key)) {
    return context;
  }
  final next = Map<String, dynamic>.from(context)..remove(key);
  return next;
}

Map<String, dynamic> _shrinkList(
  Map<String, dynamic> context,
  String key, {
  required int keep,
}) {
  final value = context[key];
  if (value is! List || value.length <= keep) {
    return context;
  }
  final next = Map<String, dynamic>.from(context);
  next[key] = value.take(keep).toList(growable: false);
  final period = next['period'];
  if (key == 'transactions' && period is Map) {
    next['period'] = {
      ...Map<String, dynamic>.from(period),
      'included_transaction_count': next[key] is List
          ? (next[key] as List).length
          : 0,
    };
  }
  return next;
}

Map<String, dynamic> _markTruncated(
  Map<String, dynamic> context, {
  required String reason,
}) {
  final next = Map<String, dynamic>.from(context);
  final integration = next['integration'];
  if (integration is Map) {
    next['integration'] = {
      ...Map<String, dynamic>.from(integration),
      'size_capped': true,
      'size_cap_reason': reason,
      'full_financial_context_included': false,
    };
  } else {
    next['integration'] = {
      'size_capped': true,
      'size_cap_reason': reason,
      'full_financial_context_included': false,
    };
  }
  return next;
}
