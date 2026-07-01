import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';

enum ChatMessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.timestamp,
    this.isStreaming = false,
    this.clarityActions = const [],
    this.attachmentLocalPath,
    this.attachmentPreviewBytes,
    this.attachmentName,
  });

  final String id;
  final ChatMessageRole role;
  final String content;
  final DateTime? timestamp;
  final bool isStreaming;
  final List<ClarityActionCard> clarityActions;
  final String? attachmentLocalPath;
  final List<int>? attachmentPreviewBytes;
  final String? attachmentName;

  bool get isUser => role == ChatMessageRole.user;

  bool get hasImageAttachment {
    if (attachmentPreviewBytes != null && attachmentPreviewBytes!.isNotEmpty) {
      return true;
    }
    final name = attachmentName ?? attachmentLocalPath ?? '';
    return attachmentLocalPath != null &&
        attachmentLocalPath!.isNotEmpty &&
        isChatImageAttachmentName(name);
  }

  bool get hasNamedAttachment =>
      attachmentName != null && attachmentName!.trim().isNotEmpty;

  ChatMessage copyWith({
    String? id,
    ChatMessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    List<ClarityActionCard>? clarityActions,
    String? attachmentLocalPath,
    List<int>? attachmentPreviewBytes,
    String? attachmentName,
    bool clearAttachmentLocalPath = false,
    bool clearAttachmentPreviewBytes = false,
    bool clearAttachmentName = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      clarityActions: clarityActions ?? this.clarityActions,
      attachmentLocalPath: clearAttachmentLocalPath
          ? null
          : attachmentLocalPath ?? this.attachmentLocalPath,
      attachmentPreviewBytes: clearAttachmentPreviewBytes
          ? null
          : attachmentPreviewBytes ?? this.attachmentPreviewBytes,
      attachmentName: clearAttachmentName
          ? null
          : attachmentName ?? this.attachmentName,
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
    this.writeKind,
    this.title,
    this.body,
    this.targetLabel,
    this.editableFields = const [],
  });

  final String id;
  final String action;
  final Map<String, dynamic> payload;
  final String confirmationText;
  final String riskLevel;
  final String status;
  final List<Map<String, dynamic>> result;
  final String? errorMessage;
  final String? writeKind;
  final String? title;
  final String? body;
  final String? targetLabel;
  final List<String> editableFields;

  factory ClarityActionCard.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    final result = json['result'];
    final editable = json['editable_fields'];
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
      writeKind: json['write_kind'] is String ? json['write_kind'] as String : null,
      title: json['title'] is String ? json['title'] as String : null,
      body: json['body'] is String ? json['body'] as String : null,
      targetLabel: json['target_label'] is String
          ? json['target_label'] as String
          : null,
      editableFields: editable is List
          ? [
              for (final item in editable)
                if (item != null) item.toString(),
            ]
          : const [],
    );
  }

  bool get isPending => status == 'pending';
  bool get isApplying => status == 'applying';
  bool get isApplied => status == 'applied';
  bool get isFailed => status == 'failed';
  bool get isDismissed => status == 'dismissed';
  bool get canConfirm => isPending || isFailed;
  bool get canDismiss => isPending || isFailed;
  bool get hasEditableFields => editableFields.isNotEmpty;
  String get actionLabel =>
      (writeKind ?? action).memoryRecordLabel;
  String get riskLabel => memoryRiskLevelLabel(riskLevel);
  String get statusLabel => memoryActionStatusLabel(status);

  ClarityActionCard copyWith({
    String? id,
    String? action,
    Map<String, dynamic>? payload,
    String? confirmationText,
    String? riskLevel,
    String? status,
    List<Map<String, dynamic>>? result,
    String? errorMessage,
    String? writeKind,
    String? title,
    String? body,
    String? targetLabel,
    List<String>? editableFields,
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
      writeKind: writeKind ?? this.writeKind,
      title: title ?? this.title,
      body: body ?? this.body,
      targetLabel: targetLabel ?? this.targetLabel,
      editableFields: editableFields ?? this.editableFields,
    );
  }
}

String _text(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}
