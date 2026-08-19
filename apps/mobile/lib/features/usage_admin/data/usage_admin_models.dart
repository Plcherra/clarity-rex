import 'package:clarity/features/usage_admin/data/usage_admin_breakdown.dart';
import 'package:clarity/l10n/app_localizations.dart';

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
    this.costBreakdown = const [],
    this.largestCostDriver,
    this.plaidItemCount = 0,
    this.plaidAccountCount = 0,
    this.plaidCostMetered = false,
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
      costBreakdown: parseCostSlices(json['cost_breakdown']),
      largestCostDriver: UsageCostDriver.fromJson(
        json['largest_cost_driver'] is Map<String, dynamic>
            ? json['largest_cost_driver'] as Map<String, dynamic>
            : null,
      ),
      plaidItemCount: _int(json['plaid_item_count']),
      plaidAccountCount: _int(json['plaid_account_count']),
      plaidCostMetered: json['plaid_cost_metered'] == true,
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
  final List<UsageCostSlice> costBreakdown;
  final UsageCostDriver? largestCostDriver;
  final int plaidItemCount;
  final int plaidAccountCount;
  final bool plaidCostMetered;

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
    required this.registeredUserCount,
    required this.monthVoiceSeconds,
    required this.monthLlmCalls,
    required this.monthChatLlmCalls,
    required this.monthVoiceLlmCalls,
    required this.monthEstimatedCostCents,
    this.costMix = const [],
    this.largestCostDriver,
    this.pricing = const UsagePricingHelper(
      cogsCents: 0,
      activeUserCount: 0,
      voiceMinutes: 0,
      costPerActiveUserCents: 0,
      costPerVoiceMinuteCents: 0,
      priceFloor2xCents: 0,
      priceFloor3xCents: 0,
      pricePerUser2xCents: 0,
      pricePerUser3xCents: 0,
      plaidIncluded: false,
    ),
    this.plaid = const UsagePlaidLinks(
      metered: false,
      userCount: 0,
      itemCount: 0,
      accountCount: 0,
    ),
  });

  factory OwnerPlatformSummary.fromJson(Map<String, dynamic> json) {
    return OwnerPlatformSummary(
      activeUserCount: _int(json['active_user_count']),
      registeredUserCount: _int(json['registered_user_count']),
      monthVoiceSeconds: _double(json['month_voice_seconds']),
      monthLlmCalls: _int(json['month_llm_calls']),
      monthChatLlmCalls: _int(json['month_chat_llm_calls']),
      monthVoiceLlmCalls: _int(json['month_voice_llm_calls']),
      monthEstimatedCostCents: _double(json['month_estimated_cost_cents']),
      costMix: parseCostSlices(json['cost_mix']),
      largestCostDriver: UsageCostDriver.fromJson(
        json['largest_cost_driver'] is Map<String, dynamic>
            ? json['largest_cost_driver'] as Map<String, dynamic>
            : null,
      ),
      pricing: UsagePricingHelper.fromJson(
        json['pricing'] is Map<String, dynamic>
            ? json['pricing'] as Map<String, dynamic>
            : null,
      ),
      plaid: UsagePlaidLinks.fromJson(
        json['plaid'] is Map<String, dynamic>
            ? json['plaid'] as Map<String, dynamic>
            : null,
      ),
    );
  }

  final int activeUserCount;
  final int registeredUserCount;
  final double monthVoiceSeconds;
  final int monthLlmCalls;
  final int monthChatLlmCalls;
  final int monthVoiceLlmCalls;
  final double monthEstimatedCostCents;
  final List<UsageCostSlice> costMix;
  final UsageCostDriver? largestCostDriver;
  final UsagePricingHelper pricing;
  final UsagePlaidLinks plaid;
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
      usageDate: _parseUsageDate(json['usage_date']),
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

String formatUsageCost(
  AppLocalizations l10n,
  double cents, {
  bool hasUsageWithoutCost = false,
}) {
  if (cents <= 0) {
    if (hasUsageWithoutCost) {
      return l10n.usageCostNotTracked;
    }
    return r'$0.00';
  }
  return '\$${(cents / 100).toStringAsFixed(2)}';
}

DateTime _parseUsageDate(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) {
      return parsed;
    }
  }
  return DateTime.utc(1970, 1, 1);
}

String formatUsageMinutes(AppLocalizations l10n, double seconds) {
  final minutes = seconds / 60;
  if (minutes < 1 && minutes > 0) {
    return l10n.usageMinutesLessThanOne;
  }
  return l10n.usageMinutesFormat(minutes.round());
}
