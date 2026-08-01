import '../../../core/models/models.dart';

/// Names the user has provably paid themselves under.
///
/// Moving money between banks often has to travel as a person-to-person
/// payment — Zelle in the US, Pix, Interac, Bizum elsewhere — so it arrives
/// described as a payment received from a person. When both sides land in the
/// user's own accounts, matching amounts already proves it was not income.
///
/// This remembers the name on those proven pairs, so the same name is still
/// recognised on the days only one side was imported, or when a fee or a
/// weekend pushed the two sides apart.
class SelfTransferNames {
  const SelfTransferNames._(this._names);

  final Set<String> _names;

  static const empty = SelfTransferNames._({});

  /// Learns from round trips: same name, same amount, opposite directions,
  /// two of the user's own accounts, within a few days. Twice is the floor,
  /// so a single reimbursement from a friend never becomes a rule.
  factory SelfTransferNames.learnedFrom(
    List<Transaction> transactions, {
    int maxDayDelta = 3,
    int minPairs = 2,
  }) {
    final named = <(Transaction, String)>[];
    for (final transaction in transactions) {
      final name = counterpartyNameFrom(transaction.description);
      if (name != null) named.add((transaction, name));
    }
    if (named.isEmpty) return empty;

    final pairsByName = <String, int>{};
    for (final (inflow, name) in named) {
      if (inflow.amount <= 0) continue;
      final hasSend = named.any(
        (other) =>
            other.$2 == name &&
            other.$1.amount < 0 &&
            other.$1.accountId != inflow.accountId &&
            (other.$1.amount.abs() - inflow.amount).abs() < 0.005 &&
            _daysBetween(other.$1.date, inflow.date) <= maxDayDelta,
      );
      if (hasSend) pairsByName[name] = (pairsByName[name] ?? 0) + 1;
    }

    final learned = {
      for (final entry in pairsByName.entries)
        if (entry.value >= minPairs) entry.key,
    };
    return learned.isEmpty ? empty : SelfTransferNames._(learned);
  }

  bool get isEmpty => _names.isEmpty;

  bool matches(String description) {
    if (_names.isEmpty) return false;
    final name = counterpartyNameFrom(description);
    return name != null && _names.contains(name);
  }
}

/// The person on the other side of a payment, lowercase, or null.
///
/// Handles the two shapes banks use: a payment phrase followed by the name,
/// and a statement line that is only the name.
String? counterpartyNameFrom(String description) {
  var text = description.toLowerCase();
  for (final noise in _trailingNoise) {
    final cut = text.indexOf(noise);
    if (cut > 0) text = text.substring(0, cut);
  }
  text = text.replaceAll(RegExp(r'[^a-zà-ÿ ]+'), ' ').trim();
  if (text.isEmpty) return null;

  final match = _payeePhrase.firstMatch(text);
  final candidate = match != null ? match.group(2)! : text;
  final tokens = candidate
      .split(RegExp(r'\s+'))
      .where((token) => token.length > 1)
      .toList();
  if (tokens.length < 2 || tokens.length > 4) return null;
  if (match == null && tokens.any(_paymentWords.contains)) return null;
  return tokens.join(' ');
}

final _payeePhrase = RegExp(
  r'\b(?:zelle|pix|venmo|interac|bizum|transfer|transferencia|payment|pagamento|pago|wire|deposit)\b[a-zà-ÿ ]*?\b(from|to|de|para|a)\b\s+(.+)$',
);

const _trailingNoise = ['conf#', 'conf #', ' for "', ' ref ', ' id:'];

const _paymentWords = <String>{
  'account',
  'atm',
  'bank',
  'card',
  'checking',
  'credit',
  'debit',
  'deposit',
  'payment',
  'purchase',
  'savings',
  'transfer',
  'withdrawal',
};

int _daysBetween(DateTime a, DateTime b) {
  return DateTime(
    a.year,
    a.month,
    a.day,
  ).difference(DateTime(b.year, b.month, b.day)).inDays.abs();
}
