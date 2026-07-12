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
      responseStyle: AssistantProposalSettings.detailed,
    );
    final restored = AssistantProposalSettings.fromJson(original.toJson());
    expect(restored, original);
  });

  test('defaults proposal mode to card', () {
    final settings = AssistantProposalSettings.fromJson({});
    expect(settings.mode, AssistantProposalSettings.card);
    expect(settings.usesConfirmCards, isTrue);
  });

  test('defaults response style to balanced', () {
    final settings = AssistantProposalSettings.fromJson({});
    expect(settings.responseStyle, AssistantProposalSettings.balanced);
  });

  test('defaults finance edits to enabled', () {
    final settings = AssistantProposalSettings.fromJson({});
    expect(settings.financeEditsEnabled, isTrue);
  });

  test('round-trips finance edits toggle', () {
    const original = AssistantProposalSettings(financeEditsEnabled: false);
    final restored = AssistantProposalSettings.fromJson(original.toJson());
    expect(restored.financeEditsEnabled, isFalse);
  });
}
