// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerNativeSession on VoiceCallController {
  bool get _shouldUseNativeVoice {
    return AppCapabilities.instance.supportsNativeVoiceBridge &&
        ref.read(nativeIosVoiceEnabledProvider) &&
        ref.read(voiceCallPlatformProvider) == TargetPlatform.iOS;
  }

  Future<bool> _startNativeVoiceSession({
    required int generation,
    required String? conversationId,
  }) async {
    final service = _nativeVoiceSessionService;
    await _nativeVoiceSubscription?.cancel();
    _nativeAssistantText = '';
    _nativeVoiceSubscription = service.events.listen(
      (event) => _handleNativeVoiceEvent(event, generation),
      onError: (Object _) {
        if (_isCurrentCall(generation)) {
          failL10n((l10n) => l10n.voiceErrorNativeSessionFailed);
        }
      },
    );

    try {
      await service.startSession(
        NativeVoiceSessionConfig(
          conversationId: conversationId,
          accessToken: const RexAuthHeaders().accessToken(),
          locale: AppLocale.rexLocaleTag(ref.read(localeControllerProvider)),
        ),
      );
    } on Object {
      await _nativeVoiceSubscription?.cancel();
      _nativeVoiceSubscription = null;
      _activeNativeVoiceSessionService = null;
      debugPrint(
        'Experimental native iOS voice bridge is unavailable. '
        'Falling back to stable cloud voice.',
      );
      return false;
    }

    if (!_isCurrentCall(generation)) {
      await service.stopSession();
      return false;
    }

    _isUsingNativeVoice = true;
    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      clearError: true,
      clearCallEndedAt: true,
    );
    return true;
  }

  void _warnIfLegacyNativeVoiceFlagRequested() {
    if (_warnedLegacyNativeVoiceFlag ||
        !ref.read(legacyNativeIosVoiceFlagRequestedProvider)) {
      return;
    }
    _warnedLegacyNativeVoiceFlag = true;
    debugPrint(
      'REX_NATIVE_IOS_VOICE_ENABLED is ignored. '
      'Use REX_EXPERIMENTAL_NATIVE_IOS_VOICE_ENABLED only for native bridge '
      'experiments; release builds use stable cloud voice.',
    );
  }

  void _handleNativeVoiceEvent(NativeVoiceEvent event, int generation) {
    if (!_isCurrentCall(generation) || !state.isCallActive) {
      return;
    }

    switch (event.name) {
      case 'session.started':
      case 'capture.started':
      case 'capture.idle_timeout':
      case 'audio.chunk':
      case 'audio.captured':
      case 'playback.queued':
      case 'transport.connecting':
      case 'transport.utterance_end_sent':
      case 'transport.closed':
      case 'foreground.changed':
      case 'capture.stopped':
      case 'capture.muted.changed':
      case 'muted.changed':
        break;
      case 'listening':
        _cancelThinkingTimeout();
        _stopBargeInMonitoring();
        _clearVisibleTranscript();
        state = state.copyWith(
          phase: VoiceCallPhase.listening,
          isCapturingSpeech: false,
          clearCurrentTranscript: true,
          clearError: true,
        );
        _markListeningReady();
        _armNoSpeechTimeout(generation);
      case 'speech.started':
        startCapturingSpeech();
      case 'speech.ended':
      case 'utterance.end':
        endpointUtterance();
      case 'transcript.partial':
        updateTranscript(event.transcript ?? state.currentTranscript);
      case 'transcript.final':
        updateTranscript(
          event.transcript ?? state.currentTranscript,
          isFinal: true,
        );
      case 'conversation.updated':
        state = state.copyWith(
          conversationId: event.conversationId,
          clearError: true,
        );
      case 'assistant.started':
        if (state.phase != VoiceCallPhase.thinking) {
          startThinking(finalTranscript: state.currentTranscript);
        }
        _nativeAssistantText = '';
        _armThinkingTimeout(generation);
      case 'assistant.token':
        _nativeAssistantText += event.token ?? '';
        _armThinkingTimeout(generation);
        state = state.copyWith(lastAssistantResponse: _nativeAssistantText);
      case 'assistant.audio_chunk':
        _cancelThinkingTimeout();
      case 'speaking.started':
        startSpeaking(
          _nativeAssistantText.isNotEmpty
              ? _nativeAssistantText
              : event.data['text'] as String? ?? state.lastAssistantResponse,
        );
        _startBargeInMonitoring(generation);
      case 'speaking.ended':
        _stopBargeInMonitoring();
      case 'assistant.done':
        _cancelThinkingTimeout();
        final responseText = event.responseText ?? _nativeAssistantText;
        state = state.copyWith(
          conversationId: event.conversationId,
          lastAssistantResponse: responseText,
          clearError: true,
        );
      case 'messages.updated':
        _applyNativeMessages(event);
      case 'session.interrupted':
        state = state.copyWith(
          phase: VoiceCallPhase.listening,
          isCapturingSpeech: false,
        );
      case 'session.ended':
        break;
      case 'error':
      case 'playback.error':
      case 'capture.error':
        final detail = event.detail?.trim();
        if (detail == null || detail.isEmpty) {
          failL10n((l10n) => l10n.voiceErrorNativeSessionFailed);
        } else {
          failVoiceApi(CloudVoiceApiException(detail));
        }
      default:
        break;
    }
  }

  void _applyNativeMessages(NativeVoiceEvent event) {
    final rawMessages = event.data['messages'];
    final conversationId = event.conversationId;
    if (conversationId == null || rawMessages is! List) {
      return;
    }

    final messages = rawMessages
        .whereType<Map<String, dynamic>>()
        .map(ChatApiMessage.fromJson)
        .toList(growable: false);
    ref
        .read(chatProvider.notifier)
        .applyBackendMessages(
          conversationId: conversationId,
          messages: messages,
          fallbackAssistantResponse: _nativeAssistantText,
          memoryChanges: event.memoryChanges,
        );
  }

  void _stopNativeVoiceSession() {
    _isUsingNativeVoice = false;
    _nativeAssistantText = '';
    final subscription = _nativeVoiceSubscription;
    _nativeVoiceSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    final service = _activeNativeVoiceSessionService;
    _activeNativeVoiceSessionService = null;
    if (service != null) {
      unawaited(service.stopSession());
    }
  }
}
