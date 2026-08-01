import '../../dashboard/domain/dashboard_insight_anchor.dart';

enum InsightSource {
  dashboardSnapshot,
  accountability,
}

enum InsightType {
  netCashFlow,
  momLeak,
  budgetOverspend,
  accountabilitySignal,
}

InsightSource insightSourceFromApiValue(String? value) {
  return switch (value) {
    'accountability' => InsightSource.accountability,
    _ => InsightSource.dashboardSnapshot,
  };
}

String insightSourceApiValue(InsightSource source) {
  return switch (source) {
    InsightSource.dashboardSnapshot => 'dashboard_snapshot',
    InsightSource.accountability => 'accountability',
  };
}

InsightType insightTypeFromApiValue(String? value) {
  return switch (value) {
    'mom_leak' => InsightType.momLeak,
    'budget_overspend' => InsightType.budgetOverspend,
    'accountability_signal' => InsightType.accountabilitySignal,
    _ => InsightType.netCashFlow,
  };
}

String insightTypeApiValue(InsightType type) {
  return switch (type) {
    InsightType.netCashFlow => 'net_cash_flow',
    InsightType.momLeak => 'mom_leak',
    InsightType.budgetOverspend => 'budget_overspend',
    InsightType.accountabilitySignal => 'accountability_signal',
  };
}

DashboardInsightAnchor? insightAnchorFromApiKey(String? value) {
  return dashboardInsightAnchorFromRouteValue(value);
}

String? insightAnchorApiKey(DashboardInsightAnchor? anchor) {
  if (anchor == null) return null;
  return dashboardInsightAnchorRouteValue(anchor);
}

class InsightItem {
  const InsightItem({
    required this.fingerprint,
    required this.source,
    required this.type,
    required this.title,
    required this.body,
    required this.periodKey,
    this.anchor,
    this.id,
    this.generatedAt,
    this.readAt,
    this.dismissedAt,
  });

  final String? id;
  final String fingerprint;
  final InsightSource source;
  final InsightType type;
  final String title;
  final String body;
  final String periodKey;
  final DashboardInsightAnchor? anchor;
  final DateTime? generatedAt;
  final DateTime? readAt;
  final DateTime? dismissedAt;

  bool get isUnread => readAt == null && dismissedAt == null;

  factory InsightItem.fromJson(Map<String, dynamic> json) {
    return InsightItem(
      id: json['id'] as String?,
      fingerprint: json['fingerprint'] as String? ?? '',
      source: insightSourceFromApiValue(json['source'] as String?),
      type: insightTypeFromApiValue(json['insight_type'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      periodKey: json['period_key'] as String? ?? '',
      anchor: insightAnchorFromApiKey(json['anchor_key'] as String?),
      generatedAt: _parseDate(json['generated_at']),
      readAt: _parseDate(json['read_at']),
      dismissedAt: _parseDate(json['dismissed_at']),
    );
  }

  Map<String, dynamic> toSyncJson() => {
    'fingerprint': fingerprint,
    'source': insightSourceApiValue(source),
    'insight_type': insightTypeApiValue(type),
    'title': title,
    'body': body,
    'period_key': periodKey,
    'anchor_key': ?insightAnchorApiKey(anchor),
  };
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

String buildInsightFingerprint({
  required InsightSource source,
  required InsightType type,
  required String periodKey,
  String? detailKey,
}) {
  final parts = [
    insightSourceApiValue(source),
    insightTypeApiValue(type),
    periodKey,
    detailKey ?? '',
  ];
  return parts.join('|');
}
