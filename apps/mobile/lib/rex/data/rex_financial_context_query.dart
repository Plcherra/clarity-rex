import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';

/// Terms extracted from a finance turn for transaction prioritization.
final class RexFinancialContextQuery {
  const RexFinancialContextQuery({
    this.merchantTerms = const [],
    this.categoryTerms = const [],
    this.budgetTerms = const [],
  });

  final List<String> merchantTerms;
  final List<String> categoryTerms;
  final List<String> budgetTerms;

  bool get hasFilters =>
      merchantTerms.isNotEmpty ||
      categoryTerms.isNotEmpty ||
      budgetTerms.isNotEmpty;

  Map<String, dynamic> toContextJson() {
    return {
      if (merchantTerms.isNotEmpty) 'merchant_terms': merchantTerms,
      if (categoryTerms.isNotEmpty) 'category_terms': categoryTerms,
      if (budgetTerms.isNotEmpty) 'budget_terms': budgetTerms,
    };
  }
}

const Set<String> _financeQueryStopWords = {
  'about',
  'afford',
  'account',
  'accounts',
  'amount',
  'and',
  'are',
  'bank',
  'budget',
  'budgets',
  'can',
  'card',
  'cards',
  'cash',
  'credit',
  'debt',
  'did',
  'do',
  'does',
  'dollar',
  'dollars',
  'finance',
  'financial',
  'for',
  'from',
  'have',
  'how',
  'income',
  'know',
  'many',
  'money',
  'month',
  'much',
  'my',
  'pay',
  'paycheck',
  'plaid',
  'should',
  'show',
  'spent',
  'spend',
  'spending',
  'that',
  'the',
  'this',
  'transaction',
  'transactions',
  'was',
  'week',
  'what',
  'when',
  'with',
  'you',
  'your',
};

RexFinancialContextQuery extractRexFinancialContextQuery(
  String message, {
  required List<BudgetRecord> budgets,
  required List<CategoryRecord> categories,
}) {
  final normalized = _normalizeFinanceQueryText(message);
  if (normalized.isEmpty) {
    return const RexFinancialContextQuery();
  }

  final budgetTerms = <String>[];
  final categoryTerms = <String>{};
  for (final budget in budgets) {
    final name = budget.name.trim();
    if (name.length < 3) {
      continue;
    }
    final normalizedName = _normalizeFinanceQueryText(name);
    if (normalized.contains(normalizedName)) {
      budgetTerms.add(name);
      categoryTerms.add(name);
    }
  }

  for (final category in categories) {
    final name = category.name.trim();
    if (name.length < 3) {
      continue;
    }
    final normalizedName = _normalizeFinanceQueryText(name);
    if (normalized.contains(normalizedName)) {
      categoryTerms.add(name);
    }
  }

  final merchantTerms = <String>{};
  for (final term in _significantFinanceTerms(normalized)) {
    merchantTerms.add(term);
  }

  for (final term in categoryTerms) {
    merchantTerms.remove(_normalizeFinanceQueryText(term));
  }
  for (final term in budgetTerms) {
    merchantTerms.remove(_normalizeFinanceQueryText(term));
  }

  return RexFinancialContextQuery(
    merchantTerms: merchantTerms.toList(growable: false),
    categoryTerms: categoryTerms.toList(growable: false),
    budgetTerms: budgetTerms,
  );
}

bool rexTransactionMatchesQuery({
  required TransactionRecord transaction,
  required ResolvedTransaction resolved,
  required RexFinancialContextQuery query,
}) {
  if (!query.hasFilters) {
    return false;
  }

  final description = _normalizeFinanceQueryText(
    '${transaction.description ?? ''} ${transaction.merchant ?? ''}',
  );
  final category = _normalizeFinanceQueryText(resolved.displayCategory);

  for (final term in query.merchantTerms) {
    if (description.contains(term)) {
      return true;
    }
  }
  for (final term in query.categoryTerms) {
    final normalizedTerm = _normalizeFinanceQueryText(term);
    if (category.contains(normalizedTerm)) {
      return true;
    }
  }
  for (final term in query.budgetTerms) {
    final normalizedTerm = _normalizeFinanceQueryText(term);
    if (category.contains(normalizedTerm)) {
      return true;
    }
  }
  return false;
}

String _normalizeFinanceQueryText(String value) {
  return value.toLowerCase().split(RegExp(r'\s+')).join(' ').trim();
}

List<String> _significantFinanceTerms(String normalizedMessage) {
  final terms = <String>[];
  for (final raw in normalizedMessage.split(RegExp(r'[^a-z0-9]+'))) {
    final term = raw.trim();
    if (term.length < 3 || _financeQueryStopWords.contains(term)) {
      continue;
    }
    if (terms.contains(term)) {
      continue;
    }
    terms.add(term);
  }
  return terms;
}
