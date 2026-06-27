import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/memory_display_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personSupplementalLabels skips details already in summary', () {
    const person = PersonMemoryItem(
      id: 'person-1',
      displayName: 'Pedro Martins',
      relationship: 'self',
      summary:
          'Full name: Pedro Martins. Lives in Somerville. Birthday: June 18. Works at Bom Dough.',
      aliases: [],
      importance: 5,
      status: 'active',
      active: true,
      metadata: {
        'attributes': {
          'full_name': 'Pedro Martins',
          'location': 'Somerville',
          'birthday': 'June 18',
          'workplace': 'Bom Dough',
          'notes': 'Works at Bom Dough',
          'important_dates': ['Launch review: 2026-06-20'],
        },
      },
    );

    expect(
      personSupplementalLabels(person),
      ['Important date: Launch review: 2026-06-20'],
    );
  });

  test('ruleMemorySubtitle hides text that matches title', () {
    const rule = RuleMemoryItem(
      id: 'rule-1',
      ruleType: 'gentle_direct',
      title: 'Be concise',
      ruleText: 'Be concise',
      triggerKeywords: [],
      priority: 3,
      status: 'active',
      active: true,
    );

    expect(ruleMemorySubtitle(rule), isNull);
  });
}
