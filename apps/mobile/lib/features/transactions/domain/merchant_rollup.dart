import 'merchant_normalization.dart';
import 'transaction_resolution.dart';

/// What one merchant took in a set of transactions.
class MerchantSpendRollup {
  const MerchantSpendRollup({
    required this.merchant,
    required this.spent,
    required this.transactionCount,
  });

  final String merchant;

  /// Positive total.
  final double spent;
  final int transactionCount;
}

/// Groups repeat visits to the same place, biggest spender first.
///
/// Raw bank descriptions carry card digits, store numbers, and dates, so a
/// daily coffee shop would otherwise read as twenty different merchants.
/// [namesByTransactionKey] lets a caller pass cleaner names (Plaid's merchant
/// field) keyed the same way the caller keys its rows.
List<MerchantSpendRollup> merchantSpendRollups(
  Iterable<ResolvedTransaction> rows, {
  Map<String, String> namesByTransactionKey = const {},
  String Function(ResolvedTransaction row)? keyOf,
  int limit = 0,
}) {
  final rawTotals = <String, double>{};
  final rawCounts = <String, int>{};
  final givenNames = <String, String>{};

  for (final row in rows) {
    final named = keyOf == null
        ? ''
        : (namesByTransactionKey[keyOf(row)] ?? '').trim();
    final key = named.isNotEmpty
        ? named.toLowerCase()
        : merchantKeyFor(row.transaction.description);
    rawTotals[key] = (rawTotals[key] ?? 0) + row.transaction.amount.abs();
    rawCounts[key] = (rawCounts[key] ?? 0) + 1;
    if (named.isNotEmpty) givenNames[key] ??= named;
  }

  // A branch, city, or payroll suffix on the end is still the same shop, so
  // every variant folds into the shortest name seen for that merchant.
  final canonical = _canonicalKeys(rawTotals.keys);
  final totals = <String, double>{};
  final counts = <String, int>{};
  final labels = <String, String>{};
  for (final entry in rawTotals.entries) {
    final key = canonical[entry.key]!;
    totals[key] = (totals[key] ?? 0) + entry.value;
    counts[key] = (counts[key] ?? 0) + rawCounts[entry.key]!;
    labels[key] ??= givenNames[key] ?? merchantDisplayLabel(key);
  }

  final sorted = totals.keys.toList()
    ..sort((a, b) {
      final bySpend = totals[b]!.compareTo(totals[a]!);
      if (bySpend != 0) return bySpend;
      return labels[a]!.compareTo(labels[b]!);
    });
  final visible = limit > 0 && sorted.length > limit
      ? sorted.sublist(0, limit)
      : sorted;

  return [
    for (final key in visible)
      MerchantSpendRollup(
        merchant: labels[key]!,
        spent: totals[key]!,
        transactionCount: counts[key]!,
      ),
  ];
}

/// Maps every key to the shortest key of its merchant family.
Map<String, String> _canonicalKeys(Iterable<String> keys) {
  final ordered = keys.toList()
    ..sort((a, b) {
      final byTokens = a.split(' ').length.compareTo(b.split(' ').length);
      return byTokens != 0 ? byTokens : a.compareTo(b);
    });

  final canonical = <String, String>{};
  final roots = <String>[];
  for (final key in ordered) {
    final root = roots.cast<String?>().firstWhere(
      (candidate) => merchantKeysAreSameFamily(candidate!, key),
      orElse: () => null,
    );
    if (root == null) {
      roots.add(key);
      canonical[key] = key;
    } else {
      canonical[key] = root;
    }
  }
  return canonical;
}

/// Stable grouping key for a description, never empty.
String merchantKeyFor(String description) {
  final normalized = merchantKeyLowerFromDescription(description);
  return normalized.isNotEmpty ? normalized : 'unknown merchant';
}

/// Turns a normalized key back into something worth showing to a person.
String merchantDisplayLabel(String key) {
  return [
    for (final word in key.split(' '))
      if (word.isNotEmpty) '${word[0].toUpperCase()}${word.substring(1)}',
  ].join(' ');
}
