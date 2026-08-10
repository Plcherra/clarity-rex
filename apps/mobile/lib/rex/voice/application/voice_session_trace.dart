import 'dart:collection';

import 'package:clarity/core/release/clarity_build_provenance.dart';

/// One ring-buffer row for owner-exportable voice session diagnostics.
///
/// Never include raw audio, credentials, or full conversation text.
class VoiceTraceEntry {
  const VoiceTraceEntry({
    required this.monotonicMs,
    required this.buildSha,
    required this.sessionId,
    required this.turnId,
    required this.event,
    required this.reason,
    required this.fromPhase,
    required this.toPhase,
  });

  final int monotonicMs;
  final String buildSha;
  final String sessionId;
  final String turnId;
  final String event;
  final String reason;
  final String fromPhase;
  final String toPhase;

  String toLine() =>
      '$monotonicMs|$buildSha|$sessionId|$turnId|$event|$reason|'
      '$fromPhase->$toPhase';
}

/// Persistent per-process ring buffer of voice pipeline authority events.
class VoiceSessionTrace {
  VoiceSessionTrace({
    this.capacity = 250,
    DateTime Function()? now,
    Stopwatch? stopwatch,
  }) : _now = now ?? DateTime.now,
       _stopwatch = stopwatch ?? (Stopwatch()..start());

  static final VoiceSessionTrace instance = VoiceSessionTrace();

  final int capacity;
  final DateTime Function() _now;
  final Stopwatch _stopwatch;
  final Queue<VoiceTraceEntry> _entries = Queue<VoiceTraceEntry>();
  String _sessionId = 'none';
  String _buildSha = ClarityBuildProvenance.gitShaDefine;

  List<VoiceTraceEntry> get entries => List.unmodifiable(_entries);

  void bindSession({required String sessionId, String? buildSha}) {
    _sessionId = sessionId;
    if (buildSha != null && buildSha.isNotEmpty) {
      _buildSha = buildSha;
    }
  }

  void clear() => _entries.clear();

  void record({
    required String event,
    required String reason,
    String turnId = '-',
    String fromPhase = '-',
    String toPhase = '-',
  }) {
    final entry = VoiceTraceEntry(
      monotonicMs: _stopwatch.elapsedMilliseconds,
      buildSha: _buildSha.length > 8 ? _buildSha.substring(0, 8) : _buildSha,
      sessionId: _sessionId,
      turnId: turnId,
      event: event,
      reason: reason,
      fromPhase: fromPhase,
      toPhase: toPhase,
    );
    _entries.addLast(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
  }

  /// Exportable text for the owner screen (no raw audio / secrets / full chat).
  String exportText({ClarityBuildProvenance? provenance}) {
    final buffer = StringBuffer();
    buffer.writeln('clarity_voice_trace');
    buffer.writeln('exported_at=${_now().toUtc().toIso8601String()}');
    if (provenance != null) {
      for (final entry in provenance.toMap().entries) {
        buffer.writeln('${entry.key}=${entry.value}');
      }
    } else {
      buffer.writeln('git_sha=${ClarityBuildProvenance.gitShaDefine}');
      buffer.writeln('git_branch=${ClarityBuildProvenance.gitBranchDefine}');
      buffer.writeln(
        'build_timestamp=${ClarityBuildProvenance.buildTimestampDefine}',
      );
    }
    buffer.writeln('session_id=$_sessionId');
    buffer.writeln('entry_count=${_entries.length}');
    buffer.writeln(
      'columns=monotonic_ms|build_sha|session_id|turn_id|event|reason|transition',
    );
    for (final entry in _entries) {
      buffer.writeln(entry.toLine());
    }
    return buffer.toString();
  }
}
