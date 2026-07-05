bool shouldAttachAssistantFinancialContext(String message) {
  final normalized = normalizedAssistantFinanceIntentText(message);
  if (normalized.isEmpty) {
    return false;
  }
  if (looksLikePastChatRecall(normalized)) {
    return false;
  }
  return hasAssistantFinanceIntent(normalized);
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
