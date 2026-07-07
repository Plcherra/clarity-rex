import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dashboard_insight_anchor.dart';

/// Increment to request navigation to Dashboard with a scroll anchor.
final dashboardDeepLinkRequestProvider =
    NotifierProvider<DashboardDeepLinkRequestNotifier, DashboardDeepLinkRequest?>(
      DashboardDeepLinkRequestNotifier.new,
    );

class DashboardDeepLinkRequest {
  const DashboardDeepLinkRequest({
    required this.anchor,
    required this.token,
  });

  final DashboardInsightAnchor anchor;
  final int token;
}

class DashboardDeepLinkRequestNotifier extends Notifier<DashboardDeepLinkRequest?> {
  var _token = 0;

  @override
  DashboardDeepLinkRequest? build() => null;

  void request(DashboardInsightAnchor anchor) {
    state = DashboardDeepLinkRequest(anchor: anchor, token: ++_token);
  }
}

bool dashboardDeepLinkOpensAccounts(DashboardInsightAnchor anchor) {
  return anchor == DashboardInsightAnchor.connectedAccounts;
}

/// Maps a finance-related user message to the closest dashboard section.
DashboardInsightAnchor? resolveDashboardInsightAnchor(String message) {
  final normalized = message.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }

  if (_matchesAny(normalized, _budgetKeywords)) {
    return DashboardInsightAnchor.budgetPerformance;
  }
  if (_matchesAny(normalized, _spendingPressureKeywords)) {
    return DashboardInsightAnchor.spendingPressure;
  }
  if (_matchesAny(normalized, _cashFlowKeywords)) {
    return DashboardInsightAnchor.monthlyCashFlow;
  }
  return DashboardInsightAnchor.monthlyCashFlow;
}

bool _matchesAny(String message, List<RegExp> patterns) {
  for (final pattern in patterns) {
    if (pattern.hasMatch(message)) {
      return true;
    }
  }
  return false;
}

final _budgetKeywords = <RegExp>[
  RegExp(r'\bbudget(?:s|ed|ing)?\b'),
  RegExp(r'\boverspend(?:ing|t)?\b'),
  RegExp(r'\bover budget\b'),
  RegExp(r'\bunder budget\b'),
  RegExp(r'\bbudgeted\b'),
];

final _spendingPressureKeywords = <RegExp>[
  RegExp(r'\bleak(?:s|ing)?\b'),
  RegExp(r'\bspending pressure\b'),
  RegExp(r'\bmonth[- ]over[- ]month\b'),
  RegExp(r'\bmom\b'),
  RegExp(r'\brising spend(?:ing)?\b'),
  RegExp(r'\bspend(?:ing)? trend\b'),
  RegExp(r'\bbiggest (?:spend|category)\b'),
];

final _cashFlowKeywords = <RegExp>[
  RegExp(r'\bspend(?:ing|t)?\b'),
  RegExp(r'\bincome\b'),
  RegExp(r'\bcash flow\b'),
  RegExp(r'\bnet (?:cash|flow)\b'),
  RegExp(r'\bbalance\b'),
  RegExp(r'\bafford\b'),
  RegExp(r'\btransaction(?:s)?\b'),
  RegExp(r'\bpayroll\b'),
  RegExp(r'\$\d'),
];
