import 'package:clarity/l10n/app_localizations.dart';

class UsageCostSlice {
  const UsageCostSlice({
    required this.id,
    required this.labelKey,
    required this.provider,
    required this.feature,
    required this.channel,
    required this.eventType,
    required this.eventCount,
    required this.unitCount,
    required this.durationMs,
    required this.estimatedCostCents,
    required this.share,
    required this.metered,
  });

  factory UsageCostSlice.fromJson(Map<String, dynamic> json) {
    return UsageCostSlice(
      id: _string(json['id']) ?? '',
      labelKey: _string(json['label_key']) ?? 'other',
      provider: _string(json['provider']) ?? '',
      feature: _string(json['feature']) ?? '',
      channel: _string(json['channel']) ?? '',
      eventType: _string(json['event_type']) ?? '',
      eventCount: _int(json['event_count']),
      unitCount: _double(json['unit_count']),
      durationMs: _int(json['duration_ms']),
      estimatedCostCents: _double(json['estimated_cost_cents']),
      share: _double(json['share']),
      metered: json['metered'] == true,
    );
  }

  final String id;
  final String labelKey;
  final String provider;
  final String feature;
  final String channel;
  final String eventType;
  final int eventCount;
  final double unitCount;
  final int durationMs;
  final double estimatedCostCents;
  final double share;
  final bool metered;
}

class UsageCostDriver {
  const UsageCostDriver({
    required this.labelKey,
    required this.estimatedCostCents,
    required this.share,
  });

  factory UsageCostDriver.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UsageCostDriver(
        labelKey: '',
        estimatedCostCents: 0,
        share: 0,
      );
    }
    return UsageCostDriver(
      labelKey: _string(json['label_key']) ?? '',
      estimatedCostCents: _double(json['estimated_cost_cents']),
      share: _double(json['share']),
    );
  }

  final String labelKey;
  final double estimatedCostCents;
  final double share;

  bool get hasDriver => labelKey.isNotEmpty && estimatedCostCents > 0;
}

class UsagePricingHelper {
  const UsagePricingHelper({
    required this.cogsCents,
    required this.activeUserCount,
    required this.voiceMinutes,
    required this.costPerActiveUserCents,
    required this.costPerVoiceMinuteCents,
    required this.priceFloor2xCents,
    required this.priceFloor3xCents,
    required this.pricePerUser2xCents,
    required this.pricePerUser3xCents,
    required this.plaidIncluded,
  });

  factory UsagePricingHelper.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UsagePricingHelper(
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
      );
    }
    return UsagePricingHelper(
      cogsCents: _double(json['cogs_cents']),
      activeUserCount: _int(json['active_user_count']),
      voiceMinutes: _double(json['voice_minutes']),
      costPerActiveUserCents: _double(json['cost_per_active_user_cents']),
      costPerVoiceMinuteCents: _double(json['cost_per_voice_minute_cents']),
      priceFloor2xCents: _double(json['price_floor_2x_cents']),
      priceFloor3xCents: _double(json['price_floor_3x_cents']),
      pricePerUser2xCents: _double(json['price_per_user_2x_cents']),
      pricePerUser3xCents: _double(json['price_per_user_3x_cents']),
      plaidIncluded: json['plaid_included'] == true,
    );
  }

  final double cogsCents;
  final int activeUserCount;
  final double voiceMinutes;
  final double costPerActiveUserCents;
  final double costPerVoiceMinuteCents;
  final double priceFloor2xCents;
  final double priceFloor3xCents;
  final double pricePerUser2xCents;
  final double pricePerUser3xCents;
  final bool plaidIncluded;
}

class UsagePlaidLinks {
  const UsagePlaidLinks({
    required this.metered,
    required this.userCount,
    required this.itemCount,
    required this.accountCount,
  });

  factory UsagePlaidLinks.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UsagePlaidLinks(
        metered: false,
        userCount: 0,
        itemCount: 0,
        accountCount: 0,
      );
    }
    return UsagePlaidLinks(
      metered: json['metered'] == true,
      userCount: _int(json['user_count']),
      itemCount: _int(json['item_count']),
      accountCount: _int(json['account_count']),
    );
  }

  final bool metered;
  final int userCount;
  final int itemCount;
  final int accountCount;

  bool get hasLinks => itemCount > 0 || accountCount > 0;
}

List<UsageCostSlice> parseCostSlices(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map<String, dynamic>>()
      .map(UsageCostSlice.fromJson)
      .toList(growable: false);
}

String usageCostSliceLabel(AppLocalizations l10n, String labelKey) {
  return switch (labelKey) {
    'grok_chat' => l10n.usageAdminSliceGrokChat,
    'grok_voice' => l10n.usageAdminSliceGrokVoice,
    'google_tts' => l10n.usageAdminSliceGoogleTts,
    'deepgram_stt' => l10n.usageAdminSliceDeepgramStt,
    'deepgram_tts' => l10n.usageAdminSliceDeepgramTts,
    'voice_session' => l10n.usageAdminSliceVoiceSession,
    'plaid' => l10n.usageAdminSlicePlaid,
    _ => l10n.usageAdminSliceOther,
  };
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
