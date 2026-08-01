import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:clarity/rex/accountability/domain/goal_deadline_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('goal deadline progress', () {
    test('a goal with no due date has nothing to measure', () {
      expect(goalDeadlineProgress(_plan()), isNull);
    });

    test('the bar fills across the run the user signed up for', () {
      final progress = goalDeadlineProgress(
        _plan(
          createdAt: DateTime(2026, 1, 1),
          targetDate: DateTime(2026, 3, 1),
        ),
        now: DateTime(2026, 2, 1),
      )!;

      // 31 of 59 days gone.
      expect(progress.elapsed, closeTo(31 / 59, 0.001));
      expect(progress.daysLeft, 28);
      expect(progress.isOverdue, isFalse);
    });

    test('a goal set today opens empty rather than part spent', () {
      final progress = goalDeadlineProgress(
        _plan(
          createdAt: DateTime(2026, 7, 1),
          targetDate: DateTime(2026, 10, 31),
        ),
        now: DateTime(2026, 7, 1),
      )!;

      expect(progress.elapsed, 0);
    });

    test('a start date the user gave wins over when the record was made', () {
      final progress = goalDeadlineProgress(
        _plan(
          createdAt: DateTime(2026, 1, 1),
          startDate: DateTime(2026, 2, 1),
          targetDate: DateTime(2026, 3, 1),
        ),
        now: DateTime(2026, 2, 15),
      )!;

      expect(progress.elapsed, closeTo(14 / 28, 0.001));
    });

    test('an overdue goal sits full and counts the days it is over', () {
      final progress = goalDeadlineProgress(
        _plan(
          createdAt: DateTime(2026, 1, 1),
          targetDate: DateTime(2026, 3, 1),
        ),
        now: DateTime(2026, 3, 6),
      )!;

      expect(progress.elapsed, 1);
      expect(progress.daysLeft, -5);
      expect(progress.isOverdue, isTrue);
      expect(progress.urgency, GoalDeadlineUrgency.overdue);
    });

    test('the due date itself is neither left nor over', () {
      final progress = goalDeadlineProgress(
        _plan(
          createdAt: DateTime(2026, 1, 1),
          targetDate: DateTime(2026, 3, 1),
        ),
        now: DateTime(2026, 3, 1),
      )!;

      expect(progress.isDueToday, isTrue);
      expect(progress.isOverdue, isFalse);
    });

    test('urgency climbs as the date closes in', () {
      GoalDeadlineUrgency at(DateTime now) => goalDeadlineProgress(
        _plan(
          createdAt: DateTime(2026, 1, 1),
          targetDate: DateTime(2027, 1, 1),
        ),
        now: now,
      )!.urgency;

      expect(at(DateTime(2026, 3, 1)), GoalDeadlineUrgency.steady);
      expect(at(DateTime(2026, 11, 1)), GoalDeadlineUrgency.closing);
      expect(at(DateTime(2026, 12, 28)), GoalDeadlineUrgency.urgent);
    });
  });
}

PlanRecord _plan({
  DateTime? createdAt,
  DateTime? startDate,
  DateTime? targetDate,
}) => PlanRecord(
  id: 'plan-1',
  planType: 'personal',
  title: 'Get a CBR600RR',
  description: null,
  desiredOutcome: null,
  priority: 4,
  status: 'active',
  active: true,
  startDate: startDate,
  targetDate: targetDate,
  targetAmount: 0,
  completedAt: null,
  lastReviewedAt: null,
  createdAt: createdAt,
);
