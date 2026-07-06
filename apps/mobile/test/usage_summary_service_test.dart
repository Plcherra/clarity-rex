import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/profile/application/usage_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VoiceUsageTotals aggregates today, week, and month', () {
    final totals = VoiceUsageTotals.fromDailyRows([
      UserVoiceSummaryRecord(
        userId: 'user-1',
        usageDate: DateTime(2026, 6, 6),
        voiceSeconds: 60,
        llmCalls: 2,
        sttSeconds: 55,
        ttsSeconds: 20,
      ),
      UserVoiceSummaryRecord(
        userId: 'user-1',
        usageDate: DateTime(2026, 6, 3),
        voiceSeconds: 120,
        llmCalls: 3,
        sttSeconds: 110,
        ttsSeconds: 30,
      ),
      UserVoiceSummaryRecord(
        userId: 'user-1',
        usageDate: DateTime(2026, 5, 31),
        voiceSeconds: 240,
        llmCalls: 4,
        sttSeconds: 220,
        ttsSeconds: 50,
      ),
    ], today: DateTime(2026, 6, 6));

    expect(totals.todayVoiceSeconds, 60);
    expect(totals.weekVoiceSeconds, 180);
    expect(totals.monthVoiceSeconds, 180);
    expect(totals.todayLlmCalls, 2);
    expect(totals.weekLlmCalls, 5);
    expect(totals.monthLlmCalls, 5);
  });

  test('UserVoiceSummaryRecord parses numeric summary fields', () {
    final record = UserVoiceSummaryRecord.fromJson({
      'user_id': 'user-1',
      'usage_date': '2026-06-06',
      'voice_seconds': '90.5',
      'llm_calls': 4,
      'stt_seconds': 80,
      'tts_seconds': '12.75',
    });

    expect(record.userId, 'user-1');
    expect(record.usageDate, DateTime(2026, 6, 6, 12));
    expect(record.voiceSeconds, 90.5);
    expect(record.llmCalls, 4);
    expect(record.sttSeconds, 80);
    expect(record.ttsSeconds, 12.75);
  });
}
