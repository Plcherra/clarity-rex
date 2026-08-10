/// Owner-visible voice transport / fallback diagnostics (no audio, no secrets).
class VoiceTransportDiagnostics {
  VoiceTransportDiagnostics();

  static final VoiceTransportDiagnostics instance = VoiceTransportDiagnostics();

  var streamingVoiceEnabled = false;
  var cloudVoiceEnabled = false;
  var manualEndpointOnly = false;

  String transport = 'unknown';
  String transportReason = 'idle';
  String webSocketState = 'idle';
  String ticketResult = 'none';
  String connectionError = '';
  String fallbackReason = 'none';
  String lastSubmitAuthority = 'none';

  void resetForCall({
    required bool streamingEnabled,
    required bool cloudEnabled,
    required bool manualOnly,
  }) {
    streamingVoiceEnabled = streamingEnabled;
    cloudVoiceEnabled = cloudEnabled;
    manualEndpointOnly = manualOnly;
    transport = streamingEnabled ? 'streaming_ws' : 'rest_cloud_capture';
    transportReason = streamingEnabled
        ? 'streaming_flag_enabled'
        : 'streaming_flag_disabled';
    webSocketState = 'idle';
    ticketResult = 'none';
    connectionError = '';
    fallbackReason = 'none';
    lastSubmitAuthority = 'none';
  }

  void setTransport(String kind, {required String reason}) {
    transport = kind;
    transportReason = reason;
  }

  void setWebSocketState(String state) {
    webSocketState = state;
  }

  void setTicketResult(String result) {
    ticketResult = result;
  }

  void setConnectionError(Object? error, {String? code}) {
    connectionError = sanitizeError(error, code: code);
  }

  void setFallbackReason(String reason) {
    fallbackReason = reason;
  }

  void setSubmitAuthority(String authority) {
    lastSubmitAuthority = authority;
  }

  /// Strip query strings / tokens that must never reach owner export.
  static String sanitizeError(Object? error, {String? code}) {
    var text = (error?.toString() ?? '').trim();
    if (text.isEmpty && (code == null || code.isEmpty)) {
      return '';
    }
    text = text
        .replaceAll(RegExp(r'(ticket|access_token|authorization)=[^&\s]+', caseSensitive: false), r'$1=***')
        .replaceAll(RegExp(r'Bearer\s+\S+', caseSensitive: false), 'Bearer ***')
        .replaceAll(RegExp(r'https?://[^\s]+'), '[url]')
        .replaceAll(RegExp(r'wss?://[^\s]+'), '[ws]');
    if (text.length > 180) {
      text = '${text.substring(0, 180)}…';
    }
    final codeText = (code ?? '').trim();
    if (codeText.isEmpty) {
      return text;
    }
    if (text.isEmpty) {
      return 'code=$codeText';
    }
    return 'code=$codeText $text';
  }

  Map<String, Object?> toMap() => {
        'REX_STREAMING_VOICE_ENABLED': streamingVoiceEnabled,
        'REX_CLOUD_VOICE_ENABLED': cloudVoiceEnabled,
        'REX_VOICE_MANUAL_ENDPOINT_ONLY': manualEndpointOnly,
        'transport': transport,
        'transport_reason': transportReason,
        'websocket_state': webSocketState,
        'ticket_result': ticketResult,
        'connection_error': connectionError,
        'fallback_reason': fallbackReason,
        'last_submit_authority': lastSubmitAuthority,
      };

  String summaryLine() {
    return 'voice_transport '
        'streaming=$streamingVoiceEnabled '
        'cloud=$cloudVoiceEnabled '
        'manual=$manualEndpointOnly '
        'transport=$transport '
        'reason=$transportReason '
        'ws=$webSocketState '
        'ticket=$ticketResult '
        'fallback=$fallbackReason '
        'submit=$lastSubmitAuthority '
        'error=${connectionError.isEmpty ? 'none' : connectionError}';
  }

  List<String> ownerLines() {
    return [
      'REX_STREAMING_VOICE_ENABLED=$streamingVoiceEnabled',
      'REX_CLOUD_VOICE_ENABLED=$cloudVoiceEnabled',
      'REX_VOICE_MANUAL_ENDPOINT_ONLY=$manualEndpointOnly',
      'transport=$transport',
      'transport_reason=$transportReason',
      'websocket_state=$webSocketState',
      'ticket_result=$ticketResult',
      'connection_error=${connectionError.isEmpty ? 'none' : connectionError}',
      'fallback_reason=$fallbackReason',
      'last_submit_authority=$lastSubmitAuthority',
    ];
  }
}
