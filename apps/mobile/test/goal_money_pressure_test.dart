import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:clarity/rex/accountability/domain/goal_money_pressure.dart';
import 'package:flutter_test/flutter_test.dart';

PlanRecord _goal({
  required String id,
  required String title,
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
    targetDate: null,
    targetAmount: amount,
    completedAt: null,
    lastReviewedAt: null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  test('totals active money goals only', () {
    final summary = buildGoalMoneyNeeds([
      _goal(id: 'bike', title: 'motorcycle', amount: 3000),
      _goal(id: 'ram', title: '16GB RAM', amount: 200),
      _goal(id: 'license', title: 'get license', amount: 0),
      _goal(id: 'old', title: 'old gear', amount: 500, status: 'completed'),
    ]);

    expect(summary.totalAmount, 3200);
    expect(summary.isEmpty, isFalse);
  });

  test('empty when nothing needs money', () {
    final summary = buildGoalMoneyNeeds([
      _goal(id: 'bike', title: 'motorcycle', amount: 0),
    ]);

    expect(summary.isEmpty, isTrue);
  });
}
