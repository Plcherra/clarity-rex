import '../../../core/models/models.dart';

class ConfirmedTransferMatch {
  const ConfirmedTransferMatch({
    required this.source,
    required this.counterpart,
  });

  final Transaction source;
  final Transaction counterpart;
}

bool _isDepository(AccountType type) {
  return type == AccountType.checking || type == AccountType.savings;
}

bool _looksLikeTransferDescription(String description) {
  final h = description.toLowerCase();
  if (h.contains('transfer from')) return true;
  if (h.contains('transfer to')) return true;
  if (h.contains('online transfer from')) return true;
  if (h.contains('online transfer to')) return true;
  if (h.contains('xfer from')) return true;
  if (h.contains('xfer to')) return true;
  if (h.contains('transfer deposit')) return true;
  if (h.contains('transfer withdrawal')) return true;
  if (h.contains('transfer') && h.contains(' from ')) return true;
  if (h.contains('transfer') && h.contains(' to ')) return true;
  if (h.contains('from savings')) return true;
  if (h.contains('from checking')) return true;
  if (h.contains('to savings')) return true;
  if (h.contains('to checking')) return true;
  return false;
}

bool _looksLikeCreditCardPaymentDescription(String description) {
  final h = description.toLowerCase();
  return h.contains('payment to crd') ||
      h.contains('payment from crd') ||
      h.contains('credit card') ||
      h.contains('autopay') ||
      h.contains('thank you');
}

bool _isCreditCardPaymentPair({
  required Transaction a,
  required Transaction b,
  required Map<String, Account> accountsById,
}) {
  final accountA = accountsById[a.accountId];
  final accountB = accountsById[b.accountId];
  if (accountA == null || accountB == null) return false;
  final involvesCreditCard =
      accountA.type == AccountType.creditCard ||
      accountB.type == AccountType.creditCard;
  if (!involvesCreditCard) return false;
  return _looksLikeCreditCardPaymentDescription(a.description) ||
      _looksLikeCreditCardPaymentDescription(b.description);
}

/// Confirms an internal move between the user's own accounts (e.g. checking ↔ savings).
///
/// Conservative: requires both sides to be depository accounts, or at least one
/// transfer-like description, and excludes credit-card payment pairs.
ConfirmedTransferMatch? findConfirmedInternalTransferMatch({
  required Transaction t,
  required List<Transaction> allTransactions,
  required Map<String, Account> accountsById,
  int maxDayDelta = 3,
}) {
  final sourceAccount = accountsById[t.accountId];
  if (sourceAccount == null) return null;

  final absAmount = t.amount.abs();
  if (!absAmount.isFinite || absAmount <= 0) return null;

  ConfirmedTransferMatch? best;
  var bestScore = -1.0;

  for (final counterpart in allTransactions) {
    if (identical(counterpart, t)) continue;
    if (counterpart.accountId == t.accountId) continue;
    if (counterpart.fingerprint == t.fingerprint) continue;

    final targetAccount = accountsById[counterpart.accountId];
    if (targetAccount == null) continue;

    if ((t.amount > 0 && counterpart.amount >= 0) ||
        (t.amount < 0 && counterpart.amount <= 0)) {
      continue;
    }
    if ((t.amount.abs() - counterpart.amount.abs()).abs() > 0.0001) continue;

    final dayDelta = _daysBetween(t.date, counterpart.date);
    if (dayDelta > maxDayDelta) continue;

    // Deliberately not compared: the names on the two sides. A person-to-person
    // rail shows whichever alias each bank has on file — a phone number at one,
    // an email at the other — so the same user moving their own money can arrive
    // under two different names. Both legs landing in accounts the user
    // connected is the stronger evidence, and it is the evidence we have.

    if (_isCreditCardPaymentPair(
      a: t,
      b: counterpart,
      accountsById: accountsById,
    )) {
      continue;
    }

    final bothDepository =
        _isDepository(sourceAccount.type) &&
        _isDepository(targetAccount.type);
    final hasTransferHint =
        _looksLikeTransferDescription(t.description) ||
        _looksLikeTransferDescription(counterpart.description);
    if (!bothDepository && !hasTransferHint) continue;

    var score = 1.0;
    score += (maxDayDelta - dayDelta) * 0.2;
    if (bothDepository) score += 0.35;
    if (hasTransferHint) score += 0.25;

    if (score > bestScore) {
      bestScore = score;
      best = ConfirmedTransferMatch(source: t, counterpart: counterpart);
    }
  }

  return best;
}

bool looksLikeInternalTransferDescription(
  String description, {
  required double amount,
}) {
  return _looksLikeTransferDescription(description);
}

/// True when the row names another account the user has connected.
///
/// Banks write an internal move using the destination account's own name —
/// `Withdrawal to 360 Performance Savings`, `Deposit from Adv Plus Banking`.
/// Matching against the user's own account list needs no keyword list and no
/// language, and unlike a bank's transfer label it cannot be true of a payment
/// to another person: only the user's own accounts are in the list.
///
/// This recognises the leg whose other side has not been imported, or lives in
/// an account connected later.
bool describesAnotherOwnAccount({
  required String description,
  required Map<String, Account> accountsById,
  required String excludingAccountId,
}) {
  final haystack = _normalizedNameTokens(description);
  if (haystack.isEmpty) return false;
  for (final account in accountsById.values) {
    if (account.id == excludingAccountId) continue;
    final name = _normalizedNameTokens(account.name);
    // A single word is too weak to be proof: an account called `Checking`
    // would swallow a payment to any business with that word in its name.
    if (name.isEmpty || !name.contains(' ')) continue;
    if (haystack.contains(name)) return true;
  }
  return false;
}

String _normalizedNameTokens(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

int _daysBetween(DateTime a, DateTime b) {
  final da = DateTime(a.year, a.month, a.day);
  final db = DateTime(b.year, b.month, b.day);
  return (da.difference(db).inDays).abs();
}
