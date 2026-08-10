class VoiceTranscriptBuffer {
  var _finalText = '';
  var _partialText = '';

  String get visible {
    final finalText = _normalize(_finalText);
    final partialText = _normalize(_partialText);
    if (finalText.isEmpty) {
      return partialText;
    }
    if (partialText.isEmpty) {
      return finalText;
    }
    if (_contains(finalText, partialText)) {
      return finalText;
    }
    if (_contains(partialText, finalText)) {
      return partialText;
    }
    return _collapseRepeatedText('$finalText $partialText');
  }

  void clear() {
    _finalText = '';
    _partialText = '';
  }

  void updatePartial(String? transcript) {
    _partialText = _normalize(transcript);
  }

  void appendFinal(String? transcript) {
    final next = _collapseRepeatedText(_normalize(transcript));
    if (next.isEmpty) {
      return;
    }

    _partialText = '';
    _appendSegment(next);
  }

  static String preferFullest(Iterable<String> parts) {
    final buffer = VoiceTranscriptBuffer();
    for (final part in parts) {
      buffer.appendFinal(part);
    }
    return buffer.visible;
  }

  /// Keep late STT polish on the same utterance lineage as [authority].
  /// Rejects sticky prior-turn prefixes that would re-stack into the bubble
  /// after finalize already chose the displayed/sent text.
  static String upgradeAuthority({
    required String authority,
    required String candidate,
  }) {
    final current = _normalize(authority);
    final next = _normalize(candidate);
    if (current.isEmpty) {
      return next;
    }
    if (next.isEmpty || _sameForComparison(current, next)) {
      return current;
    }

    final authorityWords = _wordsForComparison(current);
    final candidateWords = _wordsForComparison(next);
    if (authorityWords.isEmpty || candidateWords.isEmpty) {
      return current;
    }

    // Same turn, longer final (authority is a prefix of candidate).
    final prefixMatch = _fuzzyPrefixWordCount(authorityWords, candidateWords);
    if (_strongPrefixCoverage(prefixMatch, authorityWords.length) &&
        candidateWords.length >= authorityWords.length) {
      return next;
    }

    // Candidate is a weaker prefix of authority — keep authority.
    final reverseMatch = _fuzzyPrefixWordCount(candidateWords, authorityWords);
    if (_strongPrefixCoverage(reverseMatch, candidateWords.length) &&
        authorityWords.length >= candidateWords.length) {
      return current;
    }

    // Sticky prior + authority (+ optional extension): drop the leading junk.
    final anchor = _findFuzzySubsequenceStart(candidateWords, authorityWords);
    if (anchor > 0) {
      final displayWords = next.split(' ');
      if (displayWords.length > anchor) {
        return displayWords.skip(anchor).join(' ').trim();
      }
    }

    return current;
  }

  /// Drop a prior completed utterance when STT/interim replays it as a prefix
  /// of the next turn. Tolerates small STT drift (mind/mine, permit/permits).
  static String stripLeadingUtterance(
    String transcript, {
    String? priorUtterance,
  }) {
    final current = _normalize(transcript);
    final prior = _normalize(priorUtterance);
    if (current.isEmpty || prior.isEmpty) {
      return current;
    }
    if (_sameForComparison(current, prior)) {
      return '';
    }

    final priorWords = _wordsForComparison(prior);
    final currentWords = _wordsForComparison(current);
    if (priorWords.isEmpty || currentWords.isEmpty) {
      return current;
    }

    final matched = _fuzzyPrefixWordCount(priorWords, currentWords);
    if (matched <= 0 || !_strongPrefixCoverage(matched, priorWords.length)) {
      return current;
    }

    final displayWords = current.split(' ');
    if (displayWords.length <= matched) {
      return '';
    }
    return displayWords.skip(matched).join(' ').trim();
  }

  void _appendSegment(String transcript) {
    final next = _collapseRepeatedText(_normalize(transcript));
    if (next.isEmpty) {
      return;
    }
    if (_finalText.isEmpty) {
      _finalText = next;
      return;
    }
    if (_contains(_finalText, next)) {
      return;
    }
    if (_contains(next, _finalText)) {
      _finalText = next;
      return;
    }
    final overlap = _suffixPrefixOverlapWordCount(_finalText, next);
    if (overlap >= 2) {
      final priorWords = _finalText.split(' ');
      final nextWords = next.split(' ');
      _finalText = _collapseRepeatedText(
        [...priorWords, ...nextWords.skip(overlap)].join(' '),
      );
      return;
    }
    _finalText = _collapseRepeatedText('$_finalText $next');
  }

  static String _collapseRepeatedText(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) {
      return normalized;
    }

    final sentences = normalized
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((sentence) => sentence.trim().isNotEmpty)
        .toList(growable: false);
    if (sentences.length >= 2) {
      final collapsed = <String>[];
      for (final sentence in sentences) {
        if (collapsed.isEmpty ||
            !_sameForComparison(collapsed.last, sentence)) {
          collapsed.add(sentence);
        }
      }
      if (collapsed.length != sentences.length) {
        return _collapseAdjacentRepeatedPhrases(collapsed.join(' '));
      }
    }

    final words = normalized.split(' ');
    if (words.length >= 6 && words.length.isEven) {
      final midpoint = words.length ~/ 2;
      final firstHalf = words.take(midpoint).join(' ');
      final secondHalf = words.skip(midpoint).join(' ');
      if (_sameForComparison(firstHalf, secondHalf)) {
        return _collapseAdjacentRepeatedPhrases(firstHalf);
      }
    }
    return _collapseAdjacentRepeatedPhrases(normalized);
  }

  /// "I guess I guess" / "some some" from overlapping Deepgram finals.
  static String _collapseAdjacentRepeatedPhrases(String text) {
    final words = text
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: true);
    if (words.length < 2) {
      return text;
    }

    final output = <String>[];
    var index = 0;
    while (index < words.length) {
      var collapsed = false;
      for (var phraseLen = 3; phraseLen >= 1; phraseLen--) {
        if (index + (phraseLen * 2) > words.length) {
          continue;
        }
        final first = words.sublist(index, index + phraseLen);
        final second = words.sublist(
          index + phraseLen,
          index + (phraseLen * 2),
        );
        if (!_wordListsSimilar(first, second)) {
          continue;
        }
        output.addAll(first);
        index += phraseLen * 2;
        collapsed = true;
        break;
      }
      if (!collapsed) {
        output.add(words[index]);
        index++;
      }
    }
    return output.join(' ');
  }

  static bool _wordListsSimilar(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (!_wordsSimilar(
        _normalizeForComparison(left[index]),
        _normalizeForComparison(right[index]),
      )) {
        return false;
      }
    }
    return true;
  }

  static int _suffixPrefixOverlapWordCount(String left, String right) {
    final leftWords = _wordsForComparison(left);
    final rightWords = _wordsForComparison(right);
    if (leftWords.isEmpty || rightWords.isEmpty) {
      return 0;
    }
    final maxOverlap = leftWords.length < rightWords.length
        ? leftWords.length
        : rightWords.length;
    var best = 0;
    for (var size = maxOverlap; size >= 2; size--) {
      final suffix = leftWords.sublist(leftWords.length - size);
      final prefix = rightWords.sublist(0, size);
      if (_wordListsSimilar(suffix, prefix)) {
        best = size;
        break;
      }
    }
    return best;
  }

  static bool _contains(String text, String possibleDuplicate) {
    final normalizedText = _normalizeForComparison(text);
    final normalizedDuplicate = _normalizeForComparison(possibleDuplicate);
    return normalizedText.isNotEmpty &&
        normalizedDuplicate.isNotEmpty &&
        normalizedText.contains(normalizedDuplicate);
  }

  static bool _sameForComparison(String left, String right) {
    return _normalizeForComparison(left) == _normalizeForComparison(right);
  }

  static String _normalize(String? transcript) {
    return (transcript ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeForComparison(String? transcript) {
    return _normalize(
      transcript,
    ).toLowerCase().replaceAll(RegExp(r"[^a-z0-9']+"), ' ').trim();
  }

  static List<String> _wordsForComparison(String text) {
    return _normalizeForComparison(text)
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
  }

  static bool _strongPrefixCoverage(int matched, int priorLength) {
    if (matched <= 0 || priorLength <= 0) {
      return false;
    }
    final coverage = matched / priorLength;
    // Require a strong prefix match so unrelated turns are not mangled.
    return coverage >= 0.8 ||
        (matched >= priorLength - 1 && priorLength >= 4) ||
        (matched >= 8 && coverage >= 0.65);
  }

  static int _findFuzzySubsequenceStart(
    List<String> haystack,
    List<String> needle,
  ) {
    if (needle.isEmpty || haystack.length < needle.length) {
      return -1;
    }
    final lastStart = haystack.length - needle.length;
    for (var start = 0; start <= lastStart; start++) {
      final matched = _fuzzyPrefixWordCount(
        needle,
        haystack.sublist(start),
      );
      if (_strongPrefixCoverage(matched, needle.length)) {
        return start;
      }
    }
    return -1;
  }

  static int _fuzzyPrefixWordCount(
    List<String> priorWords,
    List<String> currentWords,
  ) {
    final limit = priorWords.length < currentWords.length
        ? priorWords.length
        : currentWords.length;
    var matched = 0;
    var misses = 0;
    for (var index = 0; index < limit; index++) {
      if (_wordsSimilar(priorWords[index], currentWords[index])) {
        matched++;
        continue;
      }
      misses++;
      // Allow a couple of drifted words inside a long sticky prefix.
      if (misses > 2 || matched < 3) {
        break;
      }
    }
    return matched;
  }

  static bool _wordsSimilar(String left, String right) {
    if (left == right) {
      return true;
    }
    if (left.length <= 2 || right.length <= 2) {
      return false;
    }
    final distance = _levenshtein(left, right);
    if (distance <= 1) {
      return true;
    }
    final maxLen = left.length > right.length ? left.length : right.length;
    return distance / maxLen <= 0.34;
  }

  static int _levenshtein(String left, String right) {
    if (left == right) {
      return 0;
    }
    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }
    final prev = List<int>.generate(right.length + 1, (index) => index);
    final curr = List<int>.filled(right.length + 1, 0);
    for (var i = 1; i <= left.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= right.length; j++) {
        final cost = left.codeUnitAt(i - 1) == right.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = prev[j] + 1;
        final insertion = curr[j - 1] + 1;
        final substitution = prev[j - 1] + cost;
        curr[j] = deletion < insertion
            ? (deletion < substitution ? deletion : substitution)
            : (insertion < substitution ? insertion : substitution);
      }
      for (var j = 0; j <= right.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[right.length];
  }
}
