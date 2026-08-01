import '../../../core/models/models.dart';
import 'bank_statement_monthly.dart';
import 'financial_role.dart';
import 'income_deposit_matcher.dart';
import 'self_transfer_names.dart';
import 'spend_categories.dart';

class ResolvedTransaction {
  const ResolvedTransaction({
    required this.transaction,
    required this.canonicalCategory,
    required this.displayCategory,
    required this.financialRole,
    required this.isStatementDataRow,
    required this.countsAsSpend,
    required this.countsAsIncome,
    required this.needsCategorization,
  });

  final Transaction transaction;
  final String canonicalCategory;
  final String displayCategory;
  final FinancialRole financialRole;

  final bool isStatementDataRow;

  /// Dashboard spend should use this only (never recompute role logic).
  final bool countsAsSpend;

  /// Dashboard income should use this only (never recompute role logic).
  final bool countsAsIncome;

  /// Uncategorized statement rows that still need a category assignment.
  final bool needsCategorization;
}

ResolvedTransaction resolveTransaction({
  required Transaction t,
  required Map<String, String> categoryOverrides,
  required Map<String, String> categoryDisplayRenamesLower,
  Map<String, String> merchantCategoryMemory = const {},
  required Map<String, Account> accountsById,
  required List<Transaction> allTransactions,
  IncomePayerIndex? incomePayers,
  SelfTransferNames? selfTransferNames,
}) {
  final labelled = _canonicalCategory(
    t,
    categoryOverrides: categoryOverrides,
    merchantCategoryMemory: merchantCategoryMemory,
    incomePayers:
        incomePayers ?? IncomePayerIndex.fromTransactions(allTransactions),
  );

  final role = effectiveFinancialRole(
    t: t,
    effectiveCategoryLabel: labelled,
    accountsById: accountsById,
    allTransactions: allTransactions,
    selfTransferNames:
        selfTransferNames ?? SelfTransferNames.learnedFrom(allTransactions),
  );

  final canonical = _labelMatchingRole(labelled, role, t.amount);
  final display = applyCategoryDisplayRenames(
    canonical,
    categoryDisplayRenamesLower,
  );

  final ignoredByCanonical = isIgnoredCategoryLabel(canonical);

  final countsSpend =
      t.amount < 0 && role == FinancialRole.expense && !ignoredByCanonical;
  final countsIncome =
      t.amount > 0 && role == FinancialRole.income && !ignoredByCanonical;

  final isStatementRow = isBankStatementDataRow(t);
  final needsCat = isStatementRow && isUnresolvedCategoryLabel(display);

  return ResolvedTransaction(
    transaction: t,
    canonicalCategory: canonical,
    displayCategory: display,
    financialRole: role,
    isStatementDataRow: isStatementRow,
    countsAsSpend: countsSpend,
    countsAsIncome: countsIncome,
    needsCategorization: needsCat,
  );
}

List<ResolvedTransaction> resolveTransactions(
  List<Transaction> txs, {
  required Map<String, String> categoryOverrides,
  required Map<String, String> categoryDisplayRenamesLower,
  Map<String, String> merchantCategoryMemory = const {},
  required Map<String, Account> accountsById,
  required List<Transaction> allTransactions,
}) {
  final incomePayers = IncomePayerIndex.fromTransactions(allTransactions);
  final selfTransferNames = SelfTransferNames.learnedFrom(allTransactions);
  return txs
      .map(
        (t) => resolveTransaction(
          t: t,
          categoryOverrides: categoryOverrides,
          categoryDisplayRenamesLower: categoryDisplayRenamesLower,
          merchantCategoryMemory: merchantCategoryMemory,
          accountsById: accountsById,
          allTransactions: allTransactions,
          incomePayers: incomePayers,
          selfTransferNames: selfTransferNames,
        ),
      )
      .toList(growable: false);
}

/// The spending bucket for a row, except that money in never lands in one.
///
/// A deposit from someone who already pays the user by direct deposit is pay,
/// even when that half of the deposit arrives with a bare merchant name and
/// inherits the category of buying there.
String _canonicalCategory(
  Transaction t, {
  required Map<String, String> categoryOverrides,
  required Map<String, String> merchantCategoryMemory,
  required IncomePayerIndex incomePayers,
}) {
  final label = spendGroupLabel(
    t,
    categoryOverrides: categoryOverrides,
    merchantCategoryMemory: merchantCategoryMemory,
  );
  if (t.amount <= 0 || incomePayers.isEmpty) return label;
  if (isIncomeCategoryLabel(label) ||
      isIgnoredCategoryLabel(label) ||
      _isMovementLabel(label)) {
    return label;
  }
  return incomePayers.incomeLabelFor(t) ?? label;
}

/// Keeps the label honest about what the row turned out to be.
///
/// A Zelle the user sends themselves arrives described as a payment received,
/// and is correctly left out of income once the sending side is found. Without
/// this, the same row still reads `Income / …` in every list — money the user
/// is told is income while the totals say otherwise.
String _labelMatchingRole(String label, FinancialRole role, double amount) {
  if (_isMovementLabel(label)) return label;
  return switch (role) {
    FinancialRole.transfer => amount >= 0 ? 'Transfer In' : 'Transfer Out',
    FinancialRole.creditCardPayment => 'Credit Card Payment',
    _ => label,
  };
}

/// Transfers and card payments move the user's own money — never reclassify.
bool _isMovementLabel(String label) {
  final normalized = label.trim().toLowerCase();
  return normalized.startsWith('transfer') ||
      normalized == 'credit card payment';
}
