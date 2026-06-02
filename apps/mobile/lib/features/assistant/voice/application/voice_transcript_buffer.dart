class VoiceTranscriptBuffer {
  var _finalText = '';
  var _partialText = '';

  String get visible {
    final finalText = _normalize(_finalText);
    final partialText = _normalize(_partialText);
    if (finalText.isEmpty) {
      return partialText;
    }
    if (partialText.isEmpty || _contains(finalText, partialText)) {
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

    final previousPartial = _normalize(_partialText);
    _partialText = '';
    if (previousPartial.isNotEmpty && !_contains(next, previousPartial)) {
      _appendSegment(previousPartial);
    }
    _appendSegment(next);
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
        return collapsed.join(' ');
      }
    }

    final words = normalized.split(' ');
    if (words.length < 6 || words.length.isOdd) {
      return normalized;
    }
    final midpoint = words.length ~/ 2;
    final firstHalf = words.take(midpoint).join(' ');
    final secondHalf = words.skip(midpoint).join(' ');
    if (_sameForComparison(firstHalf, secondHalf)) {
      return firstHalf;
    }
    return normalized;
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
}
