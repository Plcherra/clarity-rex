/// Deterministic normalization from raw bank description to a stable merchant key.
///
/// The normalizer is intentionally conservative: it removes bank/import noise
/// while preserving the smallest meaningful merchant phrase. Broad aliases are
/// only used when the variant is high-confidence.
String merchantKeyLowerFromDescription(String description) {
  var s = description.trim().toLowerCase();
  if (s.isEmpty) return '';

  // Card-not-present rows print a service phone where a store prints its city.
  final hasServicePhone = _phonePattern.hasMatch(s);

  s = _stripDatesAndReferenceFragments(s);

  // Replace punctuation with spaces, keep letters/numbers as separate tokens.
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');

  var tokens = s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return '';

  final aliasBeforeCleanup = _knownAlias(tokens);
  if (aliasBeforeCleanup != null) return aliasBeforeCleanup;

  tokens = _dropAggregatorPrefix(tokens);
  tokens = _dropNoiseAndReferences(tokens);
  tokens = _dropTrailingLocationSuffix(tokens, hasCity: !hasServicePhone);

  final aliasAfterCleanup = _knownAlias(tokens);
  if (aliasAfterCleanup != null) return aliasAfterCleanup;

  return tokens.join(' ').trim();
}

final _phonePattern = RegExp(r'\b\d{3}[- ]\d{3}[- ]\d{4}\b');

String _stripDatesAndReferenceFragments(String value) {
  var s = value;
  s = s.replaceAll(RegExp(r'\b\d{4}-\d{1,2}-\d{1,2}\b'), ' ');
  s = s.replaceAll(RegExp(r'\b\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?\b'), ' ');
  s = s.replaceAll(_phonePattern, ' ');
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

/// Removes the place a card was swiped, in any country.
///
/// Banks print location last, as `CITY REGION` or `CITY COUNTRY`. The region or
/// country code is the marker that a location block is there at all; the word
/// in front of it is the city. City names themselves are unbounded worldwide,
/// so they are found by position rather than by any list — plus the connecting
/// words that start long place names, so `SAO PAULO` and `SAN FRANCISCO` leave
/// nothing behind.
List<String> _dropTrailingLocationSuffix(
  List<String> tokens, {
  required bool hasCity,
}) {
  final result = List<String>.from(tokens);

  var sawRegionCode = false;
  while (result.length > 1 && _isLocationSuffixToken(result.last)) {
    sawRegionCode = true;
    result.removeLast();
  }
  if (!hasCity || !sawRegionCode || result.length < 2) return result;

  result.removeLast();
  while (result.length > 1 && _placeNameLeadWords.contains(result.last)) {
    result.removeLast();
  }
  return result;
}

bool _isLocationSuffixToken(String token) {
  return _directionTokens.contains(token) ||
      _regionAndCountryCodes.contains(token);
}

/// Token-wise prefix family: `bom dough coffee` covers `bom dough coffee miami`.
///
/// City and branch names are unbounded worldwide, so no list can name them.
/// Instead, a longer key that starts with a shorter one is treated as the same
/// merchant. Two tokens minimum, so `uber` never swallows `uber eats`.
bool merchantKeysAreSameFamily(String a, String b) {
  if (a == b) return true;
  final left = a.split(' ').where((token) => token.isNotEmpty).toList();
  final right = b.split(' ').where((token) => token.isNotEmpty).toList();
  final shorter = left.length <= right.length ? left : right;
  final longer = left.length <= right.length ? right : left;
  if (shorter.length < 2) return false;
  for (var i = 0; i < shorter.length; i++) {
    if (shorter[i] != longer[i]) return false;
  }
  return true;
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

const _directionTokens = <String>{'east', 'north', 'south', 'west'};

/// Words that open a multi-word place name, so the whole name goes with it.
///
/// Dropped only while walking backwards through a location block that a region
/// or country code already confirmed.
const _placeNameLeadWords = <String>{
  'bay',
  'belo',
  'campo',
  'cidade',
  'ciudad',
  'da',
  'de',
  'del',
  'di',
  'do',
  'dos',
  'east',
  'el',
  'fort',
  'la',
  'lake',
  'las',
  'les',
  'los',
  'mount',
  'new',
  'north',
  'nova',
  'novo',
  'porto',
  'puerto',
  'rio',
  'saint',
  'san',
  'santa',
  'santo',
  'sao',
  'south',
  'upper',
  'van',
  'villa',
  'west',
};

/// Trailing place codes banks append worldwide: state, province, and country
/// abbreviations. Only ever dropped from the end, and never as the last token
/// standing, so a merchant named after one of these keeps its name.
const _regionAndCountryCodes = <String>{
  // United States and territories
  'ak', 'al', 'ar', 'az', 'ca', 'co', 'ct', 'dc', 'de', 'fl', 'ga', 'hi', 'ia',
  'id', 'il', 'in', 'ks', 'ky', 'la', 'ma', 'md', 'me', 'mi', 'mn', 'mo', 'ms',
  'mt', 'nc', 'nd', 'ne', 'nh', 'nj', 'nm', 'nv', 'ny', 'oh', 'ok', 'or', 'pa',
  'pr', 'ri', 'sc', 'sd', 'tn', 'tx', 'ut', 'va', 'vi', 'vt', 'wa', 'wi', 'wv',
  'wy',
  // Canada
  'ab', 'bc', 'mb', 'nb', 'nl', 'ns', 'nt', 'nu', 'on', 'qc', 'sk', 'yt',
  // Brazil
  'ac', 'am', 'ap', 'ba', 'ce', 'df', 'es', 'go', 'mg', 'pb', 'pe', 'pi', 'rj',
  'rn', 'ro', 'rr', 'rs', 'sp', 'to',
  // Australia and Mexico ('nt' and 'wa' are already listed above)
  'act', 'nsw', 'qld', 'sa', 'tas', 'vic', 'cdmx', 'edomex', 'jal', 'nle',
  // Country codes seen at the end of card descriptions
  'ang', 'arg', 'aus', 'aut', 'bel', 'bra', 'can', 'che', 'chl', 'col', 'deu',
  'dnk', 'esp', 'fra', 'gbr', 'irl', 'ita', 'jpn', 'kor', 'mex', 'nld', 'nor',
  'nzl', 'per', 'pol', 'prt', 'swe', 'ury', 'usa', 'zaf',
};
