import 'package:clarity/core/release/clarity_build_provenance.dart';
import 'package:clarity/rex/voice/application/voice_session_trace.dart';
import 'package:clarity/rex/voice/data/voice_capture_config.dart';
import 'package:clarity/rex/voice/data/voice_vad_telemetry.dart';
import 'package:clarity/rex/voice/domain/streaming_capture_end_kind.dart';
import 'package:clarity/rex/voice/domain/voice_turn_finalize_reason.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only vadSilence capture end may authorize submit', () {
    for (final kind in StreamingCaptureEndKind.values) {
      expect(
        kind.mayAuthorizeSubmit,
        kind == StreamingCaptureEndKind.vadSilence,
      );
    }
  });

  test('max-duration finalize reason cannot submit', () {
    expect(
      VoiceTurnFinalizeReason.maxDurationRollover.maySubmitTranscript,
      isFalse,
    );
    expect(
      VoiceTurnFinalizeReason.transcriptIdleAfterVad.requiresPriorVadSilence,
      isTrue,
    );
    expect(
      VoiceTurnFinalizeReason.speechFinalAfterVad.requiresPriorVadSilence,
      isTrue,
    );
    expect(VoiceTurnFinalizeReason.vadSilence.requiresPriorVadSilence, isFalse);
  });

  test('manualStop may submit without prior VAD', () {
    expect(VoiceTurnFinalizeReason.manualStop.maySubmitTranscript, isTrue);
    expect(
      VoiceTurnFinalizeReason.manualStop.requiresPriorVadSilence,
      isFalse,
    );
  });

  test('vad telemetry tracks last-speech refresh without storing audio', () {
    final telemetry = VoiceVadTelemetry();
    const config = VoiceCaptureConfig(
      speechStartThresholdDb: -50,
      silenceThresholdDb: -58,
      silenceAfterSpeech: Duration(milliseconds: 4000),
    );
    telemetry.resetForCapture(config: config, audioRoute: 'test');
    final t0 = DateTime(2026, 8, 10, 12);
    telemetry.observeChunk(
      currentDb: -40,
      byteCount: 640,
      now: t0,
      lastSpeechRefreshed: true,
      wouldEndpoint: false,
      silenceMs: 0,
      hasSpeech: true,
    );
    telemetry.observeChunk(
      currentDb: -70,
      byteCount: 640,
      now: t0.add(const Duration(milliseconds: 450)),
      lastSpeechRefreshed: false,
      wouldEndpoint: true,
      silenceMs: 4100,
      hasSpeech: true,
    );
    final summary = telemetry.summaryLine();
    expect(summary, contains('last_speech_refresh=1'));
    expect(summary, contains('would_endpoint=1'));
    expect(summary, contains('silence_at_would=4100ms'));
    expect(summary, isNot(contains('pcm_samples')));
    expect(telemetry.toMap()['byte_count'], 1280);
  });

  test('voice session trace export omits secrets and stays bounded', () {
    final trace = VoiceSessionTrace(capacity: 3);
    trace.bindSession(sessionId: 's1', buildSha: 'abcdef123456');
    for (var i = 0; i < 5; i++) {
      trace.record(
        event: 'evt_$i',
        reason: 'r_$i',
        turnId: '$i',
        fromPhase: 'listening',
        toPhase: 'listening',
      );
    }
    expect(trace.entries, hasLength(3));
    final export = trace.exportText(
      provenance: const ClarityBuildProvenance(
        gitSha: 'abcdef123456',
        gitBranch: 'plan/04-aggressive-deletion',
        appVersion: '1.0.0',
        buildNumber: '12',
        buildTimestamp: '2026-08-10T08:00:00Z',
      ),
    );
    expect(export, contains('clarity_voice_trace'));
    expect(export, contains('build_number=12'));
    expect(export, contains('session_id=s1'));
    expect(export, isNot(contains('SUPABASE')));
    expect(export, isNot(contains('Bearer')));
    expect(export, isNot(contains('audio/pcm')));
  });
}
