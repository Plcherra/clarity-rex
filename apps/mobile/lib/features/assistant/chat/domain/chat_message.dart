enum ChatMessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.timestamp,
    this.isStreaming = false,
    this.memoryCandidates = const [],
    this.clarityActions = const [],
  });

  final String id;
  final ChatMessageRole role;
  final String content;
  final DateTime? timestamp;
  final bool isStreaming;
  final List<MemoryCandidateCard> memoryCandidates;
  final List<ClarityActionCard> clarityActions;

  bool get isUser => role == ChatMessageRole.user;

  ChatMessage copyWith({
    String? id,
    ChatMessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    List<MemoryCandidateCard>? memoryCandidates,
    List<ClarityActionCard>? clarityActions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      memoryCandidates: memoryCandidates ?? this.memoryCandidates,
      clarityActions: clarityActions ?? this.clarityActions,
    );
  }
}

class ClarityActionCard {
  const ClarityActionCard({
    required this.id,
    required this.action,
    required this.payload,
    required this.confirmationText,
    required this.riskLevel,
    this.status = 'pending',
    this.result = const [],
    this.errorMessage,
  });

  final String id;
  final String action;
  final Map<String, dynamic> payload;
  final String confirmationText;
  final String riskLevel;
  final String status;
  final List<Map<String, dynamic>> result;
  final String? errorMessage;

  factory ClarityActionCard.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    final result = json['result'];
    return ClarityActionCard(
      id: _text(json['id']),
      action: _text(json['action']),
      payload: payload is Map<String, dynamic> ? payload : const {},
      confirmationText: _text(
        json['confirmation_text'],
        fallback: 'Confirm this Clarity change?',
      ),
      riskLevel: _text(json['risk_level'], fallback: 'medium'),
      status: _text(json['status'], fallback: 'pending'),
      result: result is List
          ? [
              for (final item in result)
                if (item is Map<String, dynamic>) item,
            ]
          : const [],
      errorMessage: json['error_message'] is String
          ? json['error_message'] as String
          : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApplying => status == 'applying';
  bool get isApplied => status == 'applied';
  bool get isFailed => status == 'failed';
  bool get isDismissed => status == 'dismissed';
  bool get canConfirm => isPending || isFailed;
  bool get canDismiss => isPending || isFailed;

  ClarityActionCard copyWith({
    String? id,
    String? action,
    Map<String, dynamic>? payload,
    String? confirmationText,
    String? riskLevel,
    String? status,
    List<Map<String, dynamic>>? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ClarityActionCard(
      id: id ?? this.id,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      confirmationText: confirmationText ?? this.confirmationText,
      riskLevel: riskLevel ?? this.riskLevel,
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class MemoryCandidateCard {
  const MemoryCandidateCard({
    required this.id,
    required this.candidateType,
    required this.status,
    required this.riskLevel,
    required this.preview,
    required this.expectedAction,
    required this.requiresExplicitConfirmation,
    this.verificationPassed,
    this.verificationMessage,
    this.remainingConflictCount = 0,
  });

  final String id;
  final String candidateType;
  final String status;
  final String riskLevel;
  final String preview;
  final String expectedAction;
  final bool requiresExplicitConfirmation;
  final bool? verificationPassed;
  final String? verificationMessage;
  final int remainingConflictCount;

  factory MemoryCandidateCard.fromJson(Map<String, dynamic> json) {
    final verification = json['verification'];
    final verificationMap = verification is Map<String, dynamic>
        ? verification
        : const <String, dynamic>{};
    return MemoryCandidateCard(
      id: _text(json['id']),
      candidateType: _text(json['candidate_type']),
      status: _text(json['status'], fallback: 'pending'),
      riskLevel: _text(json['risk_level'], fallback: 'medium'),
      preview: _text(json['preview'], fallback: 'Pending memory change'),
      expectedAction: _text(
        json['expected_action'],
        fallback: 'Apply pending memory change after confirmation',
      ),
      requiresExplicitConfirmation:
          json['requires_explicit_confirmation'] == true,
      verificationPassed: verificationMap['passed'] is bool
          ? verificationMap['passed'] as bool
          : null,
      verificationMessage: verificationMap['message'] is String
          ? verificationMap['message'] as String
          : null,
      remainingConflictCount: verificationMap['remaining_conflict_count'] is int
          ? verificationMap['remaining_conflict_count'] as int
          : 0,
    );
  }

  bool get isPending => status == 'pending';
  bool get canApprove => isPending;
  bool get canReject => isPending;
}

String _text(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}
