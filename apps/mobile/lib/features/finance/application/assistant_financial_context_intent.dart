bool shouldAttachAssistantFinancialContext(
  String message, {
  Iterable<String>? recentTurnTexts,
}) {
  final normalized = normalizedAssistantFinanceIntentText(message);
  if (normalized.isEmpty) {
    return false;
  }
  if (looksLikePastChatRecall(normalized)) {
    return false;
  }
  if (hasAssistantFinanceIntent(normalized)) {
    return true;
  }
  if (recentTurnTexts == null || recentTurnTexts.isEmpty) {
    return false;
  }
  return shouldAttachFinanceFollowUpContext(
    normalized,
    recentTurnTexts: recentTurnTexts,
  );
}

String normalizedAssistantFinanceIntentText(String message) {
  return message.toLowerCase().split(RegExp(r'\s+')).join(' ').trim();
}

bool looksLikePastChatRecall(String normalized) {
  final mentionsChatHistory = assistantChatRecallPatterns.any(
    (pattern) => pattern.hasMatch(normalized),
  );
  if (!mentionsChatHistory) {
    return false;
  }
  return assistantMemoryStorePatterns.any(
    (pattern) => pattern.hasMatch(normalized),
  );
}

bool hasAssistantFinanceIntent(String normalized) {
  if (assistantDirectFinanceIntentPatterns.any(
    (pattern) => pattern.hasMatch(normalized),
  )) {
    return true;
  }
  return assistantContextualMoneyIntentPatterns.any(
    (pattern) => pattern.hasMatch(normalized),
  );
}

/// Prior chat/voice turn texts for finance follow-up attach (newest first).
///
/// Skips at most one newest entry that matches [currentMessage] so locally
/// appended in-flight user turns are not treated as prior context.
List<String> priorTurnTextsForFinanceAttach(
  Iterable<String> chronologicalContents, {
  required String currentMessage,
  int limit = 6,
}) {
  final normalizedCurrent = currentMessage.trim();
  final prior = <String>[];
  var skippedCurrent = false;
  for (final raw in chronologicalContents.toList().reversed) {
    final content = raw.trim();
    if (content.isEmpty) {
      continue;
    }
    if (!skippedCurrent &&
        normalizedCurrent.isNotEmpty &&
        content == normalizedCurrent) {
      skippedCurrent = true;
      continue;
    }
    prior.add(content);
    if (prior.length >= limit) {
      break;
    }
  }
  return prior;
}

bool recentTurnsIndicateFinanceThread(Iterable<String> recentTurnTexts) {
  // Newest-first: the most recent *substantive* topic wins. Short ok/yes and
  // "look that up" lines are skipped so they neither open nor keep a thread.
  // A newer non-finance topic (e.g. mom) closes the finance window even if an
  // older money ask is still inside the turn limit.
  for (final text in recentTurnTexts) {
    final normalized = normalizedAssistantFinanceIntentText(text);
    if (normalized.isEmpty) {
      continue;
    }
    if (_isFinanceContinuationOnly(normalized)) {
      continue;
    }
    if (hasAssistantFinanceIntent(normalized) ||
        assistantFinanceThreadSignalPatterns.any(
          (pattern) => pattern.hasMatch(normalized),
        )) {
      return true;
    }
    return false;
  }
  return false;
}

bool _isFinanceContinuationOnly(String normalized) {
  if (hasAssistantFinanceIntent(normalized)) {
    return false;
  }
  return looksLikeFinanceThreadContinuation(normalized);
}

/// True when the current message continues a finance thread without money nouns.
bool looksLikeFinanceThreadContinuation(String normalized) {
  if (normalized.isEmpty) {
    return false;
  }
  if (assistantFinanceLookupContinuationPatterns.any(
    (pattern) => pattern.hasMatch(normalized),
  )) {
    return true;
  }
  return looksLikeShortFinanceThreadContinuation(normalized);
}

bool looksLikeShortFinanceThreadContinuation(String normalized) {
  final words = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty || words.length > 12) {
    return false;
  }
  return assistantFinanceShortContinuationPatterns.any(
    (pattern) => pattern.hasMatch(normalized),
  );
}

bool shouldAttachFinanceFollowUpContext(
  String normalizedMessage, {
  required Iterable<String> recentTurnTexts,
}) {
  if (!looksLikeFinanceThreadContinuation(normalizedMessage)) {
    return false;
  }
  return recentTurnsIndicateFinanceThread(recentTurnTexts);
}

final assistantDirectFinanceIntentPatterns = <RegExp>[
  RegExp(r'\baccount balance\b'),
  RegExp(r'\bavailable balance\b'),
  RegExp(r'\bbank account(?:s)?\b'),
  RegExp(r'\bbank balance\b'),
  RegExp(r'\bbudget(?:s|ing)?\b'),
  RegExp(r'\bcash(?:\s|-)?flow\b'),
  RegExp(r'\bchecking account(?:s)?\b'),
  RegExp(r'\bcredit card(?:s)?\b'),
  RegExp(r'\bdebit card(?:s)?\b'),
  RegExp(r'\bdebt\b'),
  RegExp(r'\bexpense(?:s)?\b'),
  RegExp(r'\bfinancial(?:ly)?\b'),
  RegExp(r'\bfinance(?:s)?\b'),
  RegExp(r'\bincome\b'),
  RegExp(r'\bmerchant(?:s)?\b'),
  RegExp(r'\bplaid\b'),
  RegExp(r'\bsavings account(?:s)?\b'),
  RegExp(r'\bspend(?:ing)?\b'),
  RegExp(r'\bspent\b'),
  RegExp(r'\bsubscription(?:s)?\b'),
  RegExp(r'\btransaction(?:s)?\b'),
  RegExp(r'\$\s*\d|\b\d+(?:\.\d{2})?\s*(?:bucks|dollars)\b'),
  RegExp(r'\b(?:what|which|show|list|display|see|view)\b.{0,30}\baccounts\b'),
  RegExp(
    r'\baccounts?\b.{0,30}\b(?:balance|balances|connected|plaid|sync|synced)\b',
  ),
];

final assistantContextualMoneyIntentPatterns = <RegExp>[
  RegExp(
    r'\b(?:afford|balance|bank|budget|charge|cost|deposit|earn|earned|hit|owe|owed|paid|pay|paying|save|saved|saving|send|sending|sent|spend|spending|spent|transfer|withdraw)\b.{0,40}\b(?:money|cash|rent|bill|bills|dollar|dollars|paycheck|payroll|savings?)\b',
  ),
  RegExp(
    r'\b(?:money|cash|rent|bill|bills|dollar|dollars|paycheck|payroll|savings?)\b.{0,40}\b(?:afford|balance|bank|budget|charge|cost|deposit|earn|earned|hit|owe|owed|paid|pay|paying|save|saved|saving|send|sending|sent|spend|spending|spent|transfer|withdraw)\b',
  ),
];

final assistantChatRecallPatterns = <RegExp>[
  RegExp(r'\bchat(?:s)?\b'),
  RegExp(r'\bconversation(?:s)?\b'),
  RegExp(r'\bdid i (?:ever )?mention\b'),
  RegExp(r'\bold chat(?:s)?\b'),
  RegExp(r'\bpast chat(?:s)?\b'),
  RegExp(r'\bprevious chat(?:s)?\b'),
  RegExp(r'\btalked about\b'),
  RegExp(r'\btold you\b'),
  RegExp(r'\bhave we talked about\b'),
  RegExp(r'\bwhat did i (?:say|tell)\b'),
  RegExp(r'\bwhat have i told you\b'),
];

final assistantMemoryStorePatterns = <RegExp>[
  RegExp(r'\bchat(?:s)?\b'),
  RegExp(r'\bconversation(?:s)?\b'),
  RegExp(r'\bmemory\b'),
  RegExp(r'\bmemories\b'),
  RegExp(r'\bmention(?:ed)?\b'),
  RegExp(r'\bremember\b'),
  RegExp(r'\bs(?:ay|aid)\b'),
  RegExp(r'\bsearch\b'),
  RegExp(r'\btalked\b'),
  RegExp(r'\btell\b'),
  RegExp(r'\btold\b'),
  RegExp(r'\btold you\b'),
];

/// Assistant / unavailable copy that marks an open finance lookup thread.
final assistantFinanceThreadSignalPatterns = <RegExp>[
  RegExp(r'\bclarity financial data\b'),
  RegExp(r'\breliable .{0,40}financial data\b'),
  RegExp(r'\bfinancial (?:data|information|context)\b'),
  RegExp(r'\bfetch_(?:account_summary|spend_insight)\b'),
];

/// Permission / lookup / go-ahead language that omits money nouns.
final assistantFinanceLookupContinuationPatterns = <RegExp>[
  RegExp(r'\blook(?:\s+\w+){0,2}\s+up\b'),
  RegExp(r'\bpull(?:\s+\w+){0,2}\s+up\b'),
  RegExp(r'\b(?:please\s+)?check(?:\s+(?:it|that|this|for me))\b'),
  RegExp(r'\byes(?:\s+\w+){0,3}\s+check\b'),
  RegExp(r'\bgo ahead\b'),
  RegExp(r'\bgo for it\b'),
  RegExp(r'\bplease (?:do|check|look|fetch|pull)\b'),
  RegExp(
    r'\b(?:want|need|needed) you to (?:look|check|fetch|pull|get)\b',
  ),
  RegExp(r'\b(?:give|gave|giving) you(?:\s+my)?\s+permission\b'),
  RegExp(r'\byou have(?:\s+my)?\s+permission\b'),
  RegExp(r'\bpermission to (?:look|check|fetch|pull)\b'),
];

/// Short whole-turn continuations when a finance thread is already active.
final assistantFinanceShortContinuationPatterns = <RegExp>[
  RegExp(
    r'^(?:yes|yeah|yep|yup|ok|okay|sure|please|do it|please do|yes please|'
    r'go ahead|go for it|check(?: it| that)?(?: please)?|'
    r'look(?: it| that)? up)[.!?]*$',
  ),
];
