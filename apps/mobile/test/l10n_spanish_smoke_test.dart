import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/presentation/widgets/inline_voice_call_panel.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));

  testWidgets('auth cancel button renders in Spanish', (tester) async {
    await tester.pumpWidget(
      wrapWithSpanishL10n(
        Scaffold(body: Text(es.commonCancel)),
      ),
    );

    expect(find.text(es.commonCancel), findsOneWidget);
  });

  testWidgets('memory group headers render in Spanish', (tester) async {
    await tester.pumpWidget(
      wrapWithSpanishL10n(
        Scaffold(body: Text(es.memoryGroupPlaces)),
      ),
    );

    expect(find.text(es.memoryGroupPlaces), findsOneWidget);
    expect(es.memoryGroupPlaces, 'Lugares');
  });

  testWidgets('profile screen title renders in Spanish', (tester) async {
    await tester.pumpWidget(
      wrapWithSpanishL10n(
        Scaffold(
          appBar: AppBar(title: Text(es.profileScreenTitle)),
        ),
      ),
    );

    expect(find.text(es.profileScreenTitle), findsOneWidget);
  });

  testWidgets('dashboard overview title renders in Spanish', (tester) async {
    await tester.pumpWidget(
      wrapWithSpanishL10n(
        Scaffold(
          appBar: AppBar(title: Text(es.dashboardOverviewTitle)),
        ),
      ),
    );

    expect(find.text(es.dashboardOverviewTitle), findsOneWidget);
  });

  testWidgets('voice failure panel renders Spanish recovery copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithSpanishL10n(
        Scaffold(
          body: Column(
            children: [
              VoiceLiveTranscript(
                state: VoiceCallState(
                  phase: VoiceCallPhase.failed,
                  errorMessage: '401 unauthorized: expired token',
                ),
              ),
              InlineVoiceCallPanel(
                state: VoiceCallState(
                  phase: VoiceCallPhase.failed,
                  errorMessage: '401 unauthorized: expired token',
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

    expect(find.text(es.voiceFailureSessionReconnect), findsOneWidget);
    expect(find.byTooltip(es.voicePanelTryAgainTooltip), findsOneWidget);
  });
}
