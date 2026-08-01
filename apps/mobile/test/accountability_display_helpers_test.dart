import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:clarity/rex/accountability/presentation/accountability_display_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accountability display helpers', () {
    test('hides duplicate plan subtitle when description matches title', () {
      const plan = PlanRecord(
        id: 'plan-1',
        planType: 'personal',
        title: '2 goals. 1 buy 32-64gb ram. 2 buy 1-2tb storage',
        description: '2 goals. 1 buy 32-64gb ram. 2 buy 1-2tb storage',
        desiredOutcome: '2 goals. 1 buy 32-64gb ram. 2 buy 1-2tb storage',
        priority: 4,
        status: 'active',
        active: true,
        startDate: null,
        targetDate: null,
        targetAmount: 0,
        completedAt: null,
        lastReviewedAt: null,
      );

      expect(planSubtitle(plan), isNull);
    });

    test('keeps distinct plan notes visible', () {
      const plan = PlanRecord(
        id: 'plan-2',
        planType: 'personal',
        title: 'Buy RAM',
        description: 'Upgrade the dev machine before July.',
        desiredOutcome: 'Upgrade the dev machine before July.',
        priority: 4,
        status: 'active',
        active: true,
        startDate: null,
        targetDate: null,
        targetAmount: 0,
        completedAt: null,
        lastReviewedAt: null,
      );

      expect(
        planSubtitle(plan),
        'Upgrade the dev machine before July.',
      );
    });
  });

  group('goal steps', () {
    test('a step counts as done from status or a completion stamp', () {
      expect(isGoalStepDone(_step(id: 'a', status: 'open')), isFalse);
      expect(isGoalStepDone(_step(id: 'b', status: 'completed')), isTrue);
      expect(
        isGoalStepDone(
          _step(id: 'c', status: 'open', completedAt: DateTime(2026, 7, 1)),
        ),
        isTrue,
      );
    });

    test('what is left comes before what is finished', () {
      final sorted = sortedGoalSteps([
        _step(id: 'done', status: 'completed'),
        _step(id: 'later', status: 'open', targetDate: DateTime(2026, 9, 1)),
        _step(id: 'soon', status: 'open', targetDate: DateTime(2026, 8, 1)),
      ]);

      expect(
        sorted.map((step) => step.id),
        ['soon', 'later', 'done'],
      );
    });

    test('steps come from the matching goal in the hierarchy', () {
      final hierarchy = [
        PlanHierarchyItem(
          plan: _plan('plan-1'),
          openMilestones: [_step(id: 'open-1', status: 'open')],
          completedMilestones: [_step(id: 'done-1', status: 'completed')],
          counts: const {},
        ),
        PlanHierarchyItem(
          plan: _plan('plan-2'),
          openMilestones: [_step(id: 'other', status: 'open')],
          completedMilestones: const [],
          counts: const {},
        ),
      ];

      expect(
        goalStepsFor(hierarchy, 'plan-1').map((step) => step.id),
        ['open-1', 'done-1'],
      );
      expect(goalStepsFor(hierarchy, 'missing'), isEmpty);
    });

    test('open step count separates "none left" from "goal not found"', () {
      // The celebration escalates on the last step, so an unknown goal must
      // not read as a finished one.
      final hierarchy = [
        PlanHierarchyItem(
          plan: _plan('plan-cleared'),
          openMilestones: const [],
          completedMilestones: [_step(id: 'done-1', status: 'completed')],
          counts: const {},
        ),
        PlanHierarchyItem(
          plan: _plan('plan-busy'),
          openMilestones: [
            _step(id: 'open-1', status: 'open'),
            _step(id: 'open-2', status: 'open'),
          ],
          completedMilestones: const [],
          counts: const {},
        ),
      ];

      expect(openGoalStepCount(hierarchy, 'plan-cleared'), 0);
      expect(openGoalStepCount(hierarchy, 'plan-busy'), 2);
      expect(openGoalStepCount(hierarchy, 'missing'), isNull);
      expect(openGoalStepCount(const [], 'plan-cleared'), isNull);
    });
  });
}

PlanRecord _plan(String id) => PlanRecord(
  id: id,
  planType: 'personal',
  title: id,
  description: null,
  desiredOutcome: null,
  priority: 3,
  status: 'active',
  active: true,
  startDate: null,
  targetDate: null,
  targetAmount: 0,
  completedAt: null,
  lastReviewedAt: null,
);

PlanMilestone _step({
  required String id,
  required String status,
  DateTime? targetDate,
  DateTime? completedAt,
}) => PlanMilestone(
  id: id,
  planId: 'plan-1',
  title: id,
  description: null,
  milestoneType: 'checkpoint',
  targetDate: targetDate,
  priority: 3,
  status: status,
  active: true,
  completedAt: completedAt,
);
