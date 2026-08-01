// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

class _VoiceTurnTiming {
  _VoiceTurnTiming({
    required this.turnSequence,
    required this.turnStartedAt,
  });

  final int turnSequence;
  final DateTime turnStartedAt;
  DateTime? captureEndAt;
  DateTime? finalizeAt;
  DateTime? utteranceEndAt;
  DateTime? assistantStartedAt;
  DateTime? firstAudioAt;
  var logged = false;
}

extension VoiceCallControllerTurnTiming on VoiceCallController {
  void _beginVoiceTurnTiming(int turnSequence) {
    _activeVoiceTurnTiming = _VoiceTurnTiming(
      turnSequence: turnSequence,
      turnStartedAt: DateTime.now(),
    );
  }

  void _markVoiceTurnCaptureEnd(int turnSequence) {
    final timing = _activeVoiceTurnTiming;
    if (timing == null || timing.turnSequence != turnSequence) {
      return;
    }
    timing.captureEndAt ??= DateTime.now();
  }

  void _markVoiceTurnFinalize(int turnSequence) {
    final timing = _activeVoiceTurnTiming;
    if (timing == null || timing.turnSequence != turnSequence) {
      return;
    }
    timing.finalizeAt ??= DateTime.now();
  }

  void _markVoiceTurnUtteranceEnd(int turnSequence) {
    final timing = _activeVoiceTurnTiming;
    if (timing == null || timing.turnSequence != turnSequence) {
      return;
    }
    timing.utteranceEndAt ??= DateTime.now();
  }

  void _markVoiceTurnAssistantStarted(int turnSequence) {
    final timing = _activeVoiceTurnTiming;
    if (timing == null || timing.turnSequence != turnSequence) {
      return;
    }
    timing.assistantStartedAt ??= DateTime.now();
  }

  void _markVoiceTurnFirstAudio(int turnSequence) {
    final timing = _activeVoiceTurnTiming;
    if (timing == null || timing.turnSequence != turnSequence) {
      return;
    }
    timing.firstAudioAt ??= DateTime.now();
    _logVoiceTurnTiming(turnSequence);
  }

  void _logVoiceTurnTimingIfNeeded(int turnSequence) {
    _logVoiceTurnTiming(turnSequence);
  }

  void _logVoiceTurnTiming(int turnSequence) {
    final timing = _activeVoiceTurnTiming;
    if (timing == null ||
        timing.turnSequence != turnSequence ||
        timing.logged) {
      return;
    }
    timing.logged = true;
    final origin = timing.turnStartedAt;
    int? ms(DateTime? at) =>
        at?.difference(origin).inMilliseconds;
    debugPrint(
      'rex_voice_turn_timing turn=$turnSequence '
      'capture_end=${ms(timing.captureEndAt)} '
      'finalize=${ms(timing.finalizeAt)} '
      'utterance_end=${ms(timing.utteranceEndAt)} '
      'assistant_started=${ms(timing.assistantStartedAt)} '
      'first_audio=${ms(timing.firstAudioAt)}',
    );
  }
}
