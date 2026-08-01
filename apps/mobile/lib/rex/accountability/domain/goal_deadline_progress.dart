import 'package:clarity/rex/accountability/data/accountability_models.dart';

/// How close a goal is to its due date.
///
/// A goal has no percentage to report — "Get a CBR600RR" is not 40% done — so
/// the bar measures the one thing that is genuinely moving: the time left. It
/// fills on its own, which is the point. Nothing to keep up to date, and the
/// pressure builds whether or not the app is opened.
///
/// Kept strictly as elapsed time so nothing here can imply progress the user
/// has not actually made.
class GoalDeadlineProgress {
  const GoalDeadlineProgress({
    required this.elapsed,
    required this.daysLeft,
    required this.dueDate,
  });

  /// 0 at the start, 1 on the due date. Clamped, so an overdue goal sits full.
  final double elapsed;

  /// Negative once the date has passed.
  final int daysLeft;

  final DateTime dueDate;

  bool get isOverdue => daysLeft < 0;

  bool get isDueToday => daysLeft == 0;

  GoalDeadlineUrgency get urgency {
    if (isOverdue) return GoalDeadlineUrgency.overdue;
    if (daysLeft <= 7) return GoalDeadlineUrgency.urgent;
    if (elapsed >= 0.75) return GoalDeadlineUrgency.closing;
    return GoalDeadlineUrgency.steady;
  }
}

enum GoalDeadlineUrgency { steady, closing, urgent, overdue }

/// The window a goal is running in, or null when it has no due date.
///
/// The run starts when the goal was set, so the bar reflects the stretch the
/// user actually signed up for rather than a fixed window that would make a
/// deadline a year out look identical to one next week.
GoalDeadlineProgress? goalDeadlineProgress(PlanRecord plan, {DateTime? now}) {
  final due = plan.targetDate;
  if (due == null) return null;

  final today = _dayOf(now ?? DateTime.now());
  final dueDay = _dayOf(due);
  final start = _startOf(plan, dueDay: dueDay, today: today);

  final total = dueDay.difference(start).inDays;
  final gone = today.difference(start).inDays;
  final elapsed = total <= 0 ? 1.0 : (gone / total).clamp(0.0, 1.0);

  return GoalDeadlineProgress(
    elapsed: elapsed.toDouble(),
    daysLeft: dueDay.difference(today).inDays,
    dueDate: dueDay,
  );
}

DateTime _startOf(
  PlanRecord plan, {
  required DateTime dueDay,
  required DateTime today,
}) {
  for (final candidate in [plan.startDate, plan.createdAt]) {
    if (candidate == null) continue;
    final start = _dayOf(candidate);
    if (start.isBefore(dueDay)) return start;
  }
  // Neither date survived — a goal due today or in the past. Show it full
  // rather than empty; the deadline is what matters, not the missing start.
  return dueDay;
}

DateTime _dayOf(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
