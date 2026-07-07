import 'package:clarity/features/profile/domain/assistant_proposal_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses card mode from profile json', () {
    final settings = AssistantProposalSettings.fromJson({
      'auto_proposals_mode': 'card',
      'auto_proposals_threads': false,
    });
    expect(settings.mode, AssistantProposalSettings.card);
    expect(settings.usesConfirmCards, isTrue);
    expect(settings.threads, isFalse);
  });

  test('round-trips profile json', () {
    const original = AssistantProposalSettings(
      mode: AssistantProposalSettings.text,
      threads: true,
      goals: false,
      memory: true,
    );
    final restored = AssistantProposalSettings.fromJson(original.toJson());
    expect(restored, original);
  });
}
