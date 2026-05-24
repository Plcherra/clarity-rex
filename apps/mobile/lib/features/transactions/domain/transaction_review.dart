import '../../../core/models/models.dart';
import 'spend_categories.dart';
import 'transaction_resolution.dart';

enum TransactionReviewReason {
  needsCategory,
  internalPayment,
  manualRole,
  ignored,
}

Set<TransactionReviewReason> transactionReviewReasons(
  ResolvedTransaction transaction,
) {
  final reasons = <TransactionReviewReason>{};
  if (transaction.needsCategorization) {
    reasons.add(TransactionReviewReason.needsCategory);
  }
  if (_needsInternalPaymentReview(transaction)) {
    reasons.add(TransactionReviewReason.internalPayment);
  }
  if (transaction.transaction.financialRole != null) {
    reasons.add(TransactionReviewReason.manualRole);
  }
  if (_isIgnored(transaction)) {
    reasons.add(TransactionReviewReason.ignored);
  }
  return reasons;
}

bool transactionNeedsReview(ResolvedTransaction transaction) {
  return transactionReviewReasons(transaction).isNotEmpty;
}

bool _needsInternalPaymentReview(ResolvedTransaction transaction) {
  final category = transaction.canonicalCategory.trim().toLowerCase();
  return category == 'credit card payment' &&
      transaction.financialRole != FinancialRole.creditCardPayment;
}

bool _isIgnored(ResolvedTransaction transaction) {
  return isIgnoredCategoryLabel(transaction.displayCategory) ||
      isIgnoredCategoryLabel(transaction.canonicalCategory);
}
