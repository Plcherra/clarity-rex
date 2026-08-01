import '../data/accountability_models.dart';

/// One cumulative money checkpoint on the Goals tab.
///
/// Sorted by due date: each point is "need this much by this date" covering
/// every still-active money goal due on or before that day. Non-money goals
/// ([PlanRecord.targetAmount] of 0) do not contribute.
final class GoalMoneyPressurePoint {
  const GoalMoneyPressurePoint({
    required this.byDate,
    required this.cumulativeAmount,
    required this.titles,
  });

  final DateTime byDate;
  final double cumulativeAmount;
  final List<String> titles;
}

/// Builds the cumulative money-pressure lines for active goals.
List<GoalMoneyPressurePoint> buildGoalMoneyPressure(
  Iterable<PlanRecord> plans, {
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  // Only what still presses forward. Past money goals stay on their own tile
  // as overdue; folding them into the cumulative total would overstate what
  // the user still has to raise.
  final money =
      plans
          .where((plan) {
            if (!_isActiveGoal(plan)) return false;
            if (plan.targetAmount <= 0) return false;
            final due = plan.targetDate;
            if (due == null) return false;
            return !_dateOnly(due).isBefore(today);
          })
          .toList(growable: false)
        ..sort((a, b) {
          final byDate = a.targetDate!.compareTo(b.targetDate!);
          if (byDate != 0) return byDate;
          return a.title.compareTo(b.title);
        });

  if (money.isEmpty) return const [];

  final points = <GoalMoneyPressurePoint>[];
  var sum = 0.0;
  final titles = <String>[];
  DateTime? currentDay;

  for (final plan in money) {
    final day = _dateOnly(plan.targetDate!);
    if (currentDay != null && day != currentDay) {
      points.add(
        GoalMoneyPressurePoint(
          byDate: currentDay,
          cumulativeAmount: sum,
          titles: List<String>.unmodifiable(titles),
        ),
      );
    }
    currentDay = day;
    sum += plan.targetAmount;
    titles.add(plan.title.trim().isEmpty ? 'Goal' : plan.title.trim());
  }

  if (currentDay != null) {
    points.add(
      GoalMoneyPressurePoint(
        byDate: currentDay,
        cumulativeAmount: sum,
        titles: List<String>.unmodifiable(titles),
      ),
    );
  }

  return points;
}

bool _isActiveGoal(PlanRecord plan) {
  if (!plan.active) return false;
  final status = plan.status.trim().toLowerCase();
  return status == 'active' || status == 'paused';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
