import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:clarity/rex/accountability/domain/goal_money_pressure.dart';
import 'package:flutter_test/flutter_test.dart';

PlanRecord _goal({
  required String id,
  required String title,
  required DateTime due,
  required double amount,
  String status = 'active',
}) {
  return PlanRecord(
    id: id,
    planType: 'personal',
    title: title,
    description: null,
    desiredOutcome: null,
    priority: 4,
    status: status,
    active: true,
    startDate: null,
    targetDate: due,
    targetAmount: amount,
    completedAt: null,
    lastReviewedAt: null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  test('stacks money goals by due date into cumulative pressure', () {
    final points = buildGoalMoneyPressure(
      [
        _goal(
          id: 'bike',
          title: 'motorcycle',
          due: DateTime(2026, 10, 1),
          amount: 3000,
        ),
        _goal(
          id: 'ram',
          title: 'RAM',
          due: DateTime(2026, 12, 1),
          amount: 500,
        ),
        _goal(
          id: 'storage',
          title: 'storage',
          due: DateTime(2026, 12, 1),
          amount: 500,
        ),
        _goal(
          id: 'license',
          title: 'get license',
          due: DateTime(2026, 9, 1),
          amount: 0,
        ),
      ],
      now: DateTime(2026, 8, 1),
    );

    expect(points, hasLength(2));
    expect(points[0].cumulativeAmount, 3000);
    expect(points[0].titles, ['motorcycle']);
    expect(points[1].cumulativeAmount, 4000);
    expect(points[1].titles, ['motorcycle', 'RAM', 'storage']);
  });

  test('skips checkpoints that are already past', () {
    final points = buildGoalMoneyPressure(
      [
        _goal(
          id: 'old',
          title: 'old gear',
          due: DateTime(2026, 6, 1),
          amount: 200,
        ),
        _goal(
          id: 'bike',
          title: 'motorcycle',
          due: DateTime(2026, 10, 1),
          amount: 3000,
        ),
      ],
      now: DateTime(2026, 8, 1),
    );

    expect(points, hasLength(1));
    expect(points.single.cumulativeAmount, 3000);
    expect(points.single.titles, ['motorcycle']);
  });
}
