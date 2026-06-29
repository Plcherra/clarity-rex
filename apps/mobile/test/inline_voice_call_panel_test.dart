import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/presentation/widgets/inline_voice_call_panel.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('shows session recovery message for auth voice failures', (
    tester,
  ) async {
    await _pumpFailedVoicePanel(
      tester,
      errorMessage: '401 unauthorized: expired token',
    );

    expect(
      find.textContaining('Your Clarity session needs to reconnect'),
      findsOneWidget,
    );
    expect(find.byTooltip(l10n.voicePanelTryAgainTooltip), findsOneWidget);
    expect(find.byTooltip(l10n.voicePanelSettingsTooltip), findsOneWidget);
  });

  testWidgets('shows microphone recovery message for capture failures', (
    tester,
  ) async {
    await _pumpFailedVoicePanel(
      tester,
      errorMessage: 'Could not capture voice audio.',
    );

    expect(find.text(l10n.voiceFailureMicrophoneAccess), findsOneWidget);
  });

  testWidgets('shows audio playback recovery message for TTS failures', (
    tester,
  ) async {
    await _pumpFailedVoicePanel(
      tester,
      errorMessage: 'Could not play Rex voice for this reply.',
    );

    expect(
      find.textContaining("Rex answered, but I couldn't play the audio"),
      findsOneWidget,
    );
  });

  testWidgets('shows retry copy after repeated no-speech failures', (
    tester,
  ) async {
    await _pumpFailedVoicePanel(
      tester,
      errorMessage:
          'I still did not hear anything. Tap Try again when you are ready to use voice.',
    );

    expect(find.text(l10n.voiceFailureDidNotCatch), findsOneWidget);
  });
}

Future<void> _pumpFailedVoicePanel(
  WidgetTester tester, {
  required String errorMessage,
}) {
  return tester.pumpWidget(
    wrapWithL10n(
      Scaffold(
        body: Column(
          children: [
            VoiceLiveTranscript(
              state: VoiceCallState(
                phase: VoiceCallPhase.failed,
                errorMessage: errorMessage,
              ),
            ),
            InlineVoiceCallPanel(
              state: VoiceCallState(
                phase: VoiceCallPhase.failed,
                errorMessage: errorMessage,
              ),
              onRetry: () {},
              onEnd: () {},
              onToggleMute: () {},
              onOpenSettings: () {},
            ),
          ],
        ),
      ),
    ),
  );
}
