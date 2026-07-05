// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerChatSync on VoiceCallController {
  void _resetActiveVoiceMessageLocalId() {
    _activeVoiceMessageLocalId = null;
  }

  String _ensureActiveVoiceMessageLocalId() {
    return _activeVoiceMessageLocalId ??=
        'local-voice-${DateTime.now().microsecondsSinceEpoch}';
  }

  void _syncInterimVoiceTranscriptToChat(String content) {
    final text = content.trim();
    if (text.isEmpty) {
      return;
    }

    ref.read(chatProvider.notifier).upsertVoiceUserMessage(
      localId: _ensureActiveVoiceMessageLocalId(),
      content: text,
    );
  }

  void _finalizeVoiceTranscriptInChat({String? finalTranscript}) {
    final text = (finalTranscript ?? _transcriptBuffer.visible).trim();
    if (text.isEmpty) {
      _removeActiveVoiceUserMessage();
      return;
    }

    ref.read(chatProvider.notifier).finalizeVoiceUserMessage(
      localId: _ensureActiveVoiceMessageLocalId(),
      content: text,
    );
  }

  void _removeActiveVoiceUserMessage() {
    final localId = _activeVoiceMessageLocalId;
    if (localId == null) {
      return;
    }

    ref.read(chatProvider.notifier).removeVoiceUserMessage(localId);
    _resetActiveVoiceMessageLocalId();
  }
}
