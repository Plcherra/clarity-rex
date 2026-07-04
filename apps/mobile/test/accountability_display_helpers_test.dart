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
        completedAt: null,
        lastReviewedAt: null,
      );

      expect(
        planSubtitle(plan),
        'Upgrade the dev machine before July.',
      );
    });
  });
}
