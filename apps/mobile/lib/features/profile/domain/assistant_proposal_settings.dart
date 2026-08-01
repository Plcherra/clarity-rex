final class AssistantProposalSettings {
  const AssistantProposalSettings({
    this.mode = AssistantProposalSettings.off,
    this.threads = true,
    this.goals = true,
    this.memory = true,
  });

  static const off = 'off';
  static const text = 'text';
  static const card = 'card';

  final String mode;
  final bool threads;
  final bool goals;
  final bool memory;

  bool get enabled => mode != off;

  bool get usesTextOffers => mode == text;

  bool get usesConfirmCards => mode == card;

  factory AssistantProposalSettings.fromJson(Map<String, dynamic>? json) {
    final payload = json ?? const {};
    final rawMode = (payload['auto_proposals_mode'] as String?)?.trim();
    final mode = switch (rawMode) {
      off => off,
      text => text,
      card => card,
      // Missing/blank/invalid → Off (never silent Card autos).
      _ => off,
    };
    return AssistantProposalSettings(
      mode: mode,
      threads: payload['auto_proposals_threads'] as bool? ?? true,
      goals: payload['auto_proposals_goals'] as bool? ?? true,
      memory: payload['auto_proposals_memory'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'auto_proposals_mode': mode,
    'auto_proposals_threads': threads,
    'auto_proposals_goals': goals,
    'auto_proposals_memory': memory,
  };

  AssistantProposalSettings copyWith({
    String? mode,
    bool? threads,
    bool? goals,
    bool? memory,
  }) {
    return AssistantProposalSettings(
      mode: mode ?? this.mode,
      threads: threads ?? this.threads,
      goals: goals ?? this.goals,
      memory: memory ?? this.memory,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssistantProposalSettings &&
        other.mode == mode &&
        other.threads == threads &&
        other.goals == goals &&
        other.memory == memory;
  }

  @override
  int get hashCode => Object.hash(mode, threads, goals, memory);
}

enum AssistantProposalMode { off, text, card }

extension AssistantProposalModeValue on AssistantProposalMode {
  String get storageValue => switch (this) {
    AssistantProposalMode.off => AssistantProposalSettings.off,
    AssistantProposalMode.text => AssistantProposalSettings.text,
    AssistantProposalMode.card => AssistantProposalSettings.card,
  };

  static AssistantProposalMode fromStorage(String? raw) {
    return switch (raw?.trim()) {
      AssistantProposalSettings.off => AssistantProposalMode.off,
      AssistantProposalSettings.text => AssistantProposalMode.text,
      AssistantProposalSettings.card => AssistantProposalMode.card,
      _ => AssistantProposalMode.off,
    };
  }
}
