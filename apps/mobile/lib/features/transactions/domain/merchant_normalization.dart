/// Deterministic normalization from raw bank description to a stable merchant key.
///
/// The normalizer is intentionally conservative: it removes bank/import noise
/// while preserving the smallest meaningful merchant phrase. Broad aliases are
/// only used when the variant is high-confidence.
String merchantKeyLowerFromDescription(String description) {
  var s = description.trim().toLowerCase();
  if (s.isEmpty) return '';

  s = _stripDatesAndReferenceFragments(s);

  // Replace punctuation with spaces, keep letters/numbers as separate tokens.
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');

  var tokens = s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return '';

  final aliasBeforeCleanup = _knownAlias(tokens);
  if (aliasBeforeCleanup != null) return aliasBeforeCleanup;

  tokens = _dropAggregatorPrefix(tokens);
  tokens = _dropNoiseAndReferences(tokens);
  tokens = _dropTrailingLocationSuffix(tokens);

  final aliasAfterCleanup = _knownAlias(tokens);
  if (aliasAfterCleanup != null) return aliasAfterCleanup;

  return tokens.join(' ').trim();
}

String _stripDatesAndReferenceFragments(String value) {
  var s = value;
  s = s.replaceAll(RegExp(r'\b\d{4}-\d{1,2}-\d{1,2}\b'), ' ');
  s = s.replaceAll(RegExp(r'\b\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?\b'), ' ');
  s = s.replaceAll(RegExp(r'\b\d{3}[- ]\d{3}[- ]\d{4}\b'), ' ');
  s = s.replaceAll(RegExp(r'#\s*[a-z0-9]*\d+[a-z0-9]*'), ' ');
  s = s.replaceAll(RegExp(r'\b[x*]{2,}[a-z0-9]*\b'), ' ');
  return s;
}

List<String> _dropAggregatorPrefix(List<String> tokens) {
  if (tokens.length < 2) return tokens;

  const aggregators = <String>{
    'paypal',
    'pypl',
    'sq',
    'square',
    'stripe',
    'tst',
    'toast',
  };

  final first = tokens.first;
  if (!aggregators.contains(first)) return tokens;

  final withoutPrefix = tokens.sublist(1);
  final cleaned = _dropNoiseAndReferences(withoutPrefix);
  return cleaned.isEmpty ? tokens : withoutPrefix;
}

List<String> _dropNoiseAndReferences(List<String> tokens) {
  final kept = <String>[];
  for (final token in tokens) {
    if (_noiseTokens.contains(token)) continue;
    if (RegExp(r'^\d+$').hasMatch(token)) continue;
    if (RegExp(r'^[a-z]*\d+[a-z0-9]*$').hasMatch(token)) continue;
    kept.add(token);
  }
  return kept;
}

List<String> _dropTrailingLocationSuffix(List<String> tokens) {
  final result = List<String>.from(tokens);
  while (result.length > 1 && _locationSuffixTokens.contains(result.last)) {
    result.removeLast();
  }
  return result;
}

String? _knownAlias(List<String> tokens) {
  if (tokens.isEmpty) return null;

  final first = tokens.first;
  if (first == 'dunkin') return 'dunkin';
  if (first == 'dd') return 'dunkin';
  if (tokens.length >= 2 && first == 'dunkin' && tokens[1] == 'donuts') {
    return 'dunkin';
  }
  if (tokens.length >= 2 && first == 'dd' && tokens[1] == 'br') {
    return 'dunkin';
  }

  return null;
}

const _noiseTokens = <String>{
  'ach',
  'auth',
  'authorization',
  'card',
  'conf',
  'confirmation',
  'credit',
  'debit',
  'id',
  'mc',
  'mobile',
  'online',
  'payment',
  'payments',
  'pos',
  'purchase',
  'purchased',
  'recurring',
  'ref',
  'reference',
  'refund',
  'return',
  'transaction',
  'transfer',
  'txn',
  'visa',
};

const _locationSuffixTokens = <String>{
  'ak',
  'al',
  'ar',
  'az',
  'ca',
  'co',
  'ct',
  'dc',
  'de',
  'east',
  'fl',
  'ga',
  'hi',
  'ia',
  'id',
  'il',
  'in',
  'ks',
  'ky',
  'la',
  'ma',
  'md',
  'me',
  'mi',
  'mn',
  'mo',
  'ms',
  'mt',
  'nc',
  'nd',
  'ne',
  'nh',
  'nj',
  'nm',
  'north',
  'nv',
  'ny',
  'oh',
  'ok',
  'or',
  'pa',
  'ri',
  'sc',
  'sd',
  'south',
  'tn',
  'tx',
  'ut',
  'va',
  'vt',
  'wa',
  'west',
  'wi',
  'wv',
  'wy',
  'boston',
  'brookline',
  'cambridge',
  'quincy',
  'somerville',
};
