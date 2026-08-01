import '../data/accountability_models.dart';

/// Total dollars still needed across active money goals.
///
/// Per-goal amounts live on each card. This is only the rollup under the list.
final class GoalMoneyNeedsSummary {
  const GoalMoneyNeedsSummary({required this.totalAmount});

  final double totalAmount;

  bool get isEmpty => totalAmount <= 0;
  bool get isNotEmpty => !isEmpty;
}

/// Sum of active goals that need money.
GoalMoneyNeedsSummary buildGoalMoneyNeeds(Iterable<PlanRecord> plans) {
  var total = 0.0;
  for (final plan in plans) {
    if (!_isActiveGoal(plan) || plan.targetAmount <= 0) continue;
    total += plan.targetAmount;
  }
  return GoalMoneyNeedsSummary(totalAmount: total);
}

bool _isActiveGoal(PlanRecord plan) {
  if (!plan.active) return false;
  final status = plan.status.trim().toLowerCase();
  return status == 'active' || status == 'paused';
}
