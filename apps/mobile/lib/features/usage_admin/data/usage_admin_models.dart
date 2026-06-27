class OwnerUserUsage {
  const OwnerUserUsage({
    required this.userId,
    required this.email,
    required this.monthVoiceSeconds,
    required this.monthLlmCalls,
    required this.monthChatLlmCalls,
    required this.monthVoiceLlmCalls,
    required this.monthSttSeconds,
    required this.monthTtsSeconds,
    required this.monthEstimatedCostCents,
  });

  factory OwnerUserUsage.fromJson(Map<String, dynamic> json) {
    return OwnerUserUsage(
      userId: _string(json['user_id']) ?? '',
      email: _string(json['email']),
      monthVoiceSeconds: _double(json['month_voice_seconds']),
      monthLlmCalls: _int(json['month_llm_calls']),
      monthChatLlmCalls: _int(json['month_chat_llm_calls']),
      monthVoiceLlmCalls: _int(json['month_voice_llm_calls']),
      monthSttSeconds: _double(json['month_stt_seconds']),
      monthTtsSeconds: _double(json['month_tts_seconds']),
      monthEstimatedCostCents: _double(json['month_estimated_cost_cents']),
    );
  }

  final String userId;
  final String? email;
  final double monthVoiceSeconds;
  final int monthLlmCalls;
  final int monthChatLlmCalls;
  final int monthVoiceLlmCalls;
  final double monthSttSeconds;
  final double monthTtsSeconds;
  final double monthEstimatedCostCents;

  String get displayLabel {
    final value = email?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    if (userId.length <= 8) {
      return userId;
    }
    return '${userId.substring(0, 8)}…';
  }
}

class OwnerPlatformSummary {
  const OwnerPlatformSummary({
    required this.activeUserCount,
    required this.monthVoiceSeconds,
    required this.monthLlmCalls,
    required this.monthChatLlmCalls,
    required this.monthVoiceLlmCalls,
    required this.monthEstimatedCostCents,
  });

  factory OwnerPlatformSummary.fromJson(Map<String, dynamic> json) {
    return OwnerPlatformSummary(
      activeUserCount: _int(json['active_user_count']),
      monthVoiceSeconds: _double(json['month_voice_seconds']),
      monthLlmCalls: _int(json['month_llm_calls']),
      monthChatLlmCalls: _int(json['month_chat_llm_calls']),
      monthVoiceLlmCalls: _int(json['month_voice_llm_calls']),
      monthEstimatedCostCents: _double(json['month_estimated_cost_cents']),
    );
  }

  final int activeUserCount;
  final double monthVoiceSeconds;
  final int monthLlmCalls;
  final int monthChatLlmCalls;
  final int monthVoiceLlmCalls;
  final double monthEstimatedCostCents;
}

class OwnerUserDailyUsage {
  const OwnerUserDailyUsage({
    required this.userId,
    required this.email,
    required this.daily,
  });

  factory OwnerUserDailyUsage.fromJson(Map<String, dynamic> json) {
    final rows = json['daily'];
    return OwnerUserDailyUsage(
      userId: _string(json['user_id']) ?? '',
      email: _string(json['email']),
      daily: rows is List
          ? rows
                .whereType<Map<String, dynamic>>()
                .map(OwnerDailyUsageRow.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  final String userId;
  final String? email;
  final List<OwnerDailyUsageRow> daily;
}

class OwnerDailyUsageRow {
  const OwnerDailyUsageRow({
    required this.usageDate,
    required this.voiceSeconds,
    required this.llmCalls,
    required this.chatLlmCalls,
    required this.voiceLlmCalls,
    required this.sttSeconds,
    required this.ttsSeconds,
    required this.estimatedCostCents,
  });

  factory OwnerDailyUsageRow.fromJson(Map<String, dynamic> json) {
    return OwnerDailyUsageRow(
      usageDate: DateTime.parse(_string(json['usage_date']) ?? '1970-01-01'),
      voiceSeconds: _double(json['voice_seconds']),
      llmCalls: _int(json['llm_calls']),
      chatLlmCalls: _int(json['chat_llm_calls']),
      voiceLlmCalls: _int(json['voice_llm_calls']),
      sttSeconds: _double(json['stt_seconds']),
      ttsSeconds: _double(json['tts_seconds']),
      estimatedCostCents: _double(json['estimated_cost_cents']),
    );
  }

  final DateTime usageDate;
  final double voiceSeconds;
  final int llmCalls;
  final int chatLlmCalls;
  final int voiceLlmCalls;
  final double sttSeconds;
  final double ttsSeconds;
  final double estimatedCostCents;
}

String? _string(Object? value) => value is String ? value : null;

double _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return 0;
}

int _int(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

String formatUsageCost(double cents) {
  if (cents <= 0) {
    return r'$0.00';
  }
  return '\$${(cents / 100).toStringAsFixed(2)}';
}

String formatUsageMinutes(double seconds) {
  final minutes = seconds / 60;
  if (minutes < 1 && minutes > 0) {
    return '<1 min';
  }
  return '${minutes.round()} min';
}
