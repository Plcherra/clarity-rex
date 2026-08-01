import '../../../core/models/models.dart';
import 'merchant_normalization.dart';
import 'merchant_rollup.dart';
import 'spend_categories.dart';

/// Payers whose deposits are already recognised as income somewhere.
///
/// Banks describe the same direct deposit differently per account: one side
/// arrives as `ACME LLC DES:PAYROLL ID:… INDN:…`, the other as a bare
/// `ACME LLC`. The bare half then inherits whatever category the merchant has
/// from buying there, which is how a paycheck ends up filed as coffee — money
/// in, sitting in a spending bucket, counted as neither income nor spend.
///
/// This collects the merchants that pay, so the quiet half can be recognised
/// as pay too. It reads only labels and descriptions already on the rows; it
/// never guesses that an unknown deposit is income.
class IncomePayerIndex {
  const IncomePayerIndex._(this._payers);

  final Map<String, String> _payers;

  static const empty = IncomePayerIndex._({});

  factory IncomePayerIndex.fromTransactions(List<Transaction> transactions) {
    final payers = <String, String>{};
    for (final transaction in transactions) {
      if (transaction.amount <= 0) continue;
      final label = _declaredIncomeLabel(transaction);
      if (label == null) continue;
      final key = merchantKeyFor(transaction.description);
      // Shortest wins so the bare description is the family root.
      final existing = payers.keys.where(
        (candidate) => merchantKeysAreSameFamily(candidate, key),
      );
      if (existing.isEmpty) {
        payers[key] = label;
        continue;
      }
      final root = existing.reduce(
        (a, b) => a.split(' ').length <= b.split(' ').length ? a : b,
      );
      if (key.split(' ').length < root.split(' ').length) {
        payers.remove(root);
        payers[key] = label;
      }
    }
    return IncomePayerIndex._(payers);
  }

  bool get isEmpty => _payers.isEmpty;

  /// The income category this payer's deposits belong in, or null.
  String? incomeLabelFor(Transaction transaction) {
    if (_payers.isEmpty || transaction.amount <= 0) return null;
    final key = merchantKeyFor(transaction.description);
    for (final entry in _payers.entries) {
      if (merchantKeysAreSameFamily(entry.key, key)) return entry.value;
    }
    return null;
  }
}

/// The income category a row already declares on its own, if any.
String? _declaredIncomeLabel(Transaction transaction) {
  final saved = transaction.categoryLabel?.trim();
  if (saved != null && saved.isNotEmpty && isIncomeCategoryLabel(saved)) {
    return saved;
  }
  final suggested = suggestCategoryFromDescription(
    transaction.description,
    amount: transaction.amount,
  );
  return isIncomeCategoryLabel(suggested) ? suggested : null;
}
