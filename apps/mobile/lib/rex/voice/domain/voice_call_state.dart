enum VoiceCallPhase { idle, listening, thinking, speaking, failed }

class VoiceCallState {
  const VoiceCallState({
    this.phase = VoiceCallPhase.idle,
    this.currentTranscript = '',
    this.lastAssistantResponse = '',
    this.conversationId,
    this.errorMessage,
    this.callStartedAt,
    this.callEndedAt,
    this.isMuted = false,
    this.listeningReadySignal = 0,
    this.isCapturingSpeech = false,
    this.thinkingStartedAt,
    this.lastThoughtDuration,
  });

  final VoiceCallPhase phase;
  final String currentTranscript;
  final String lastAssistantResponse;
  final String? conversationId;
  final String? errorMessage;
  final DateTime? callStartedAt;
  final DateTime? callEndedAt;
  final bool isMuted;
  final int listeningReadySignal;
  final bool isCapturingSpeech;
  final DateTime? thinkingStartedAt;
  final Duration? lastThoughtDuration;

  bool get isIdle => phase == VoiceCallPhase.idle;

  bool get isCallActive {
    return switch (phase) {
      VoiceCallPhase.listening ||
      VoiceCallPhase.thinking ||
      VoiceCallPhase.speaking => true,
      VoiceCallPhase.idle || VoiceCallPhase.failed => false,
    };
  }

  bool get isBusy {
    return switch (phase) {
      VoiceCallPhase.thinking || VoiceCallPhase.speaking => true,
      VoiceCallPhase.idle ||
      VoiceCallPhase.listening ||
      VoiceCallPhase.failed => false,
    };
  }

  bool get canStartCall {
    return phase == VoiceCallPhase.idle || phase == VoiceCallPhase.failed;
  }

  bool get canEndCall => isCallActive || phase == VoiceCallPhase.failed;

  Duration callDuration({DateTime? now}) {
    final startedAt = callStartedAt;
    if (startedAt == null) {
      return Duration.zero;
    }

    final endedAt = callEndedAt ?? now ?? DateTime.now();
    if (endedAt.isBefore(startedAt)) {
      return Duration.zero;
    }

    return endedAt.difference(startedAt);
  }

  Duration thinkingElapsed({DateTime? now}) {
    final startedAt = thinkingStartedAt;
    if (startedAt == null || phase != VoiceCallPhase.thinking) {
      return Duration.zero;
    }

    final current = now ?? DateTime.now();
    if (current.isBefore(startedAt)) {
      return Duration.zero;
    }

    return current.difference(startedAt);
  }

  VoiceCallState copyWith({
    VoiceCallPhase? phase,
    String? currentTranscript,
    String? lastAssistantResponse,
    String? conversationId,
    String? errorMessage,
    DateTime? callStartedAt,
    DateTime? callEndedAt,
    bool? isMuted,
    int? listeningReadySignal,
    bool? isCapturingSpeech,
    DateTime? thinkingStartedAt,
    Duration? lastThoughtDuration,
    bool clearCurrentTranscript = false,
    bool clearLastAssistantResponse = false,
    bool clearConversationId = false,
    bool clearError = false,
    bool clearCallStartedAt = false,
    bool clearCallEndedAt = false,
    bool clearThinkingStartedAt = false,
    bool clearLastThoughtDuration = false,
  }) {
    return VoiceCallState(
      phase: phase ?? this.phase,
      currentTranscript: clearCurrentTranscript
          ? ''
          : currentTranscript ?? this.currentTranscript,
      lastAssistantResponse: clearLastAssistantResponse
          ? ''
          : lastAssistantResponse ?? this.lastAssistantResponse,
      conversationId: clearConversationId
          ? null
          : conversationId ?? this.conversationId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      callStartedAt: clearCallStartedAt
          ? null
          : callStartedAt ?? this.callStartedAt,
      callEndedAt: clearCallEndedAt ? null : callEndedAt ?? this.callEndedAt,
      isMuted: isMuted ?? this.isMuted,
      listeningReadySignal: listeningReadySignal ?? this.listeningReadySignal,
      isCapturingSpeech: isCapturingSpeech ?? this.isCapturingSpeech,
      thinkingStartedAt: clearThinkingStartedAt
          ? null
          : thinkingStartedAt ?? this.thinkingStartedAt,
      lastThoughtDuration: clearLastThoughtDuration
          ? null
          : lastThoughtDuration ?? this.lastThoughtDuration,
    );
  }
}
