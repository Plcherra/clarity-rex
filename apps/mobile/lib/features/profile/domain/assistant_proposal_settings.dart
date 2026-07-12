final class AssistantProposalSettings {
  const AssistantProposalSettings({
    this.mode = AssistantProposalSettings.card,
    this.threads = true,
    this.goals = true,
    this.memory = true,
    this.responseStyle = AssistantProposalSettings.balanced,
    this.financeEditsEnabled = true,
  });

  static const off = 'off';
  static const text = 'text';
  static const card = 'card';

  static const concise = 'concise';
  static const balanced = 'balanced';
  static const detailed = 'detailed';

  final String mode;
  final bool threads;
  final bool goals;
  final bool memory;
  final String responseStyle;
  final bool financeEditsEnabled;

  bool get enabled => mode != off;

  bool get usesTextOffers => mode == text;

  bool get usesConfirmCards => mode == card;

  factory AssistantProposalSettings.fromJson(Map<String, dynamic>? json) {
    final payload = json ?? const {};
    final rawMode = (payload['auto_proposals_mode'] as String? ?? card).trim();
    final mode = switch (rawMode) {
      off => off,
      text => text,
      _ => card,
    };
    final rawStyle =
        (payload['response_style'] as String? ?? balanced).trim().toLowerCase();
    final responseStyle = switch (rawStyle) {
      concise => concise,
      detailed => detailed,
      _ => balanced,
    };
    return AssistantProposalSettings(
      mode: mode,
      threads: payload['auto_proposals_threads'] as bool? ?? true,
      goals: payload['auto_proposals_goals'] as bool? ?? true,
      memory: payload['auto_proposals_memory'] as bool? ?? true,
      responseStyle: responseStyle,
      financeEditsEnabled: payload['finance_edits_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'auto_proposals_mode': mode,
    'auto_proposals_threads': threads,
    'auto_proposals_goals': goals,
    'auto_proposals_memory': memory,
    'response_style': responseStyle,
    'finance_edits_enabled': financeEditsEnabled,
  };

  AssistantProposalSettings copyWith({
    String? mode,
    bool? threads,
    bool? goals,
    bool? memory,
    String? responseStyle,
    bool? financeEditsEnabled,
  }) {
    return AssistantProposalSettings(
      mode: mode ?? this.mode,
      threads: threads ?? this.threads,
      goals: goals ?? this.goals,
      memory: memory ?? this.memory,
      responseStyle: responseStyle ?? this.responseStyle,
      financeEditsEnabled: financeEditsEnabled ?? this.financeEditsEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssistantProposalSettings &&
        other.mode == mode &&
        other.threads == threads &&
        other.goals == goals &&
        other.memory == memory &&
        other.responseStyle == responseStyle &&
        other.financeEditsEnabled == financeEditsEnabled;
  }

  @override
  int get hashCode =>
      Object.hash(mode, threads, goals, memory, responseStyle, financeEditsEnabled);
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
      _ => AssistantProposalMode.card,
    };
  }
}

enum AssistantResponseStyle { concise, balanced, detailed }

extension AssistantResponseStyleValue on AssistantResponseStyle {
  String get storageValue => switch (this) {
    AssistantResponseStyle.concise => AssistantProposalSettings.concise,
    AssistantResponseStyle.balanced => AssistantProposalSettings.balanced,
    AssistantResponseStyle.detailed => AssistantProposalSettings.detailed,
  };

  static AssistantResponseStyle fromStorage(String? raw) {
    return switch (raw?.trim()) {
      AssistantProposalSettings.concise => AssistantResponseStyle.concise,
      AssistantProposalSettings.detailed => AssistantResponseStyle.detailed,
      _ => AssistantResponseStyle.balanced,
    };
  }
}
