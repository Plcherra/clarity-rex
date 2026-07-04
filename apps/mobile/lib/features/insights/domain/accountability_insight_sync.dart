import 'package:clarity/rex/accountability/data/accountability_models.dart';

List<Map<String, dynamic>> accountabilitySignalsForInsightSync(
  AccountabilityOverview overview,
) {
  final seen = <String>{};
  final payload = <Map<String, dynamic>>[];

  for (final signal in [
    ...overview.signals,
    ...overview.ruleRisks,
    ...overview.recentPatterns,
  ]) {
    if (signal.status != AccountabilityStatus.active) continue;
    final id = signal.id?.trim();
    final dedupeKey = id?.isNotEmpty == true ? id! : signal.title;
    if (!seen.add(dedupeKey)) continue;
    payload.add({
      'id': id,
      'signal_type': accountabilitySignalTypeKey(signal.signalType),
      'title': signal.title,
      'summary': signal.summary,
      'reason': signal.reason,
      'status': 'active',
    });
  }

  return payload;
}

String accountabilitySignalTypeKey(AccountabilitySignalType type) {
  return switch (type) {
    AccountabilitySignalType.ruleViolation => 'rule_violation',
    AccountabilitySignalType.planDrift => 'plan_drift',
    AccountabilitySignalType.repeatedPattern => 'repeated_pattern',
    AccountabilitySignalType.upcomingDeadline => 'upcoming_deadline',
    AccountabilitySignalType.budgetRisk => 'budget_risk',
    AccountabilitySignalType.positiveFollowThrough => 'positive_follow_through',
    AccountabilitySignalType.unknown => 'accountability_signal',
  };
}
