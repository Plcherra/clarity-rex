import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../../core/supabase/supabase_service.dart';

final class UsageSummaryService {
  UsageSummaryService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  Future<VoiceUsageTotals> fetchVoiceUsageTotals({DateTime? today}) async {
    final currentDay = _dateOnly(today ?? DateTime.now());
    final monthStart = DateTime(currentDay.year, currentDay.month);
    try {
      final rows = await _supabaseService.client
          .from('user_voice_summaries')
          .select()
          .gte('usage_date', _dateString(monthStart))
          .order('usage_date');
      final summaries = rows
          .map<UserVoiceSummaryRecord>(UserVoiceSummaryRecord.fromJson)
          .toList();
      return VoiceUsageTotals.fromDailyRows(summaries, today: currentDay);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'user_voice_summaries',
        action: 'fetchVoiceUsageTotals',
        message: 'Could not load voice usage.',
        cause: e,
      );
    }
  }
}

final class VoiceUsageTotals {
  const VoiceUsageTotals({
    required this.todayVoiceSeconds,
    required this.weekVoiceSeconds,
    required this.monthVoiceSeconds,
    required this.todayLlmCalls,
    required this.weekLlmCalls,
    required this.monthLlmCalls,
    required this.dailyRows,
  });

  final double todayVoiceSeconds;
  final double weekVoiceSeconds;
  final double monthVoiceSeconds;
  final int todayLlmCalls;
  final int weekLlmCalls;
  final int monthLlmCalls;
  final List<UserVoiceSummaryRecord> dailyRows;

  factory VoiceUsageTotals.empty() {
    return const VoiceUsageTotals(
      todayVoiceSeconds: 0,
      weekVoiceSeconds: 0,
      monthVoiceSeconds: 0,
      todayLlmCalls: 0,
      weekLlmCalls: 0,
      monthLlmCalls: 0,
      dailyRows: [],
    );
  }

  factory VoiceUsageTotals.fromDailyRows(
    List<UserVoiceSummaryRecord> rows, {
    required DateTime today,
  }) {
    final day = _dateOnly(today);
    final weekStart = day.subtract(Duration(days: day.weekday - 1));
    final monthStart = DateTime(day.year, day.month);
    var todayVoiceSeconds = 0.0;
    var weekVoiceSeconds = 0.0;
    var monthVoiceSeconds = 0.0;
    var todayLlmCalls = 0;
    var weekLlmCalls = 0;
    var monthLlmCalls = 0;

    for (final row in rows) {
      final usageDate = _dateOnly(row.usageDate);
      if (usageDate.isBefore(monthStart)) continue;
      monthVoiceSeconds += row.voiceSeconds;
      monthLlmCalls += row.llmCalls;
      if (!usageDate.isBefore(weekStart)) {
        weekVoiceSeconds += row.voiceSeconds;
        weekLlmCalls += row.llmCalls;
      }
      if (usageDate == day) {
        todayVoiceSeconds += row.voiceSeconds;
        todayLlmCalls += row.llmCalls;
      }
    }

    return VoiceUsageTotals(
      todayVoiceSeconds: todayVoiceSeconds,
      weekVoiceSeconds: weekVoiceSeconds,
      monthVoiceSeconds: monthVoiceSeconds,
      todayLlmCalls: todayLlmCalls,
      weekLlmCalls: weekLlmCalls,
      monthLlmCalls: monthLlmCalls,
      dailyRows: rows,
    );
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _dateString(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
