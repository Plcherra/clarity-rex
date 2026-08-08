import 'package:clarity/features/dashboard/domain/dashboard_insight_anchor.dart';

/// Picks a category name to show on the finance deep-link chip instead of a
/// generic "Dashboard" label.
String? financeDeepLinkCategoryLabel({
  required DashboardInsightAnchor? anchor,
  required String userMessage,
  Map<String, dynamic>? financialContext,
  String? assistantReply,
}) {
  if (anchor == null || anchor == DashboardInsightAnchor.connectedAccounts) {
    return null;
  }

  final categories = _categoryNamesFromContext(financialContext);
  final mentioned = _categoryMentionedInText(
    userMessage,
    categories,
  );
  if (mentioned != null) {
    return mentioned;
  }

  final fromReply = _categoryMentionedInText(
    assistantReply ?? '',
    categories,
  );
  if (fromReply != null) {
    return fromReply;
  }

  if (categories.isEmpty) {
    return null;
  }
  // Vague spend questions: use the top bucket (often Miscellaneous).
  return categories.first;
}

List<String> _categoryNamesFromContext(Map<String, dynamic>? financialContext) {
  if (financialContext == null) {
    return const [];
  }
  final names = <String>[];
  void addFrom(Object? raw) {
    if (raw is! List) {
      return;
    }
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final name = item['category']?.toString().trim();
      if (name != null &&
          name.isNotEmpty &&
          !name.startsWith('__') &&
          !names.contains(name)) {
        names.add(name);
      }
    }
  }

  addFrom(financialContext['top_spending_categories']);
  addFrom(financialContext['biggest_month_over_month_increases']);
  final spendThisMonth = financialContext['category_spend_this_month'];
  if (spendThisMonth is Map) {
    for (final key in spendThisMonth.keys) {
      final name = key.toString().trim();
      if (name.isNotEmpty &&
          !name.startsWith('__') &&
          !names.contains(name)) {
        names.add(name);
      }
    }
  }
  return names;
}

String? _categoryMentionedInText(String message, List<String> categories) {
  final haystack = message.toLowerCase();
  if (haystack.trim().isEmpty || categories.isEmpty) {
    return null;
  }

  String? best;
  var bestScore = 0;
  for (final category in categories) {
    final score = _mentionScore(haystack, category);
    if (score > bestScore) {
      best = category.trim();
      bestScore = score;
    }
  }
  return best;
}

/// Full-name match wins; otherwise any significant token (≥4 chars) in the
/// category that appears in the text (e.g. "coffee" → "Coffee / Quick Food").
int _mentionScore(String haystack, String category) {
  final needle = category.trim().toLowerCase();
  if (needle.length < 3) {
    return 0;
  }
  if (haystack.contains(needle)) {
    return 1000 + needle.length;
  }

  var bestToken = 0;
  for (final raw in needle.split(RegExp(r'[^a-z0-9]+'))) {
    final token = raw.trim();
    if (token.length < 4) {
      continue;
    }
    if (haystack.contains(token) && token.length > bestToken) {
      bestToken = token.length;
    }
  }
  return bestToken;
}
