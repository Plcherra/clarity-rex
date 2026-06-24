part of 'accountability_page.dart';

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: RexUiTokens.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: RexUiTokens.space8),
        if (children.isEmpty)
          RexSurface(
            color: RexUiTokens.surfaceSoft.withValues(alpha: 0.6),
            borderColor: RexUiTokens.border.withValues(alpha: 0.58),
            padding: const EdgeInsets.all(RexUiTokens.space16),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: RexUiTokens.textSubtle,
                  size: 18,
                ),
                const SizedBox(width: RexUiTokens.space8),
                Expanded(
                  child: Text(
                    emptyText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: RexUiTokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  const SizedBox(height: RexUiTokens.space8),
              ],
            ],
          ),
      ],
    );
  }
}

class _GoalTileShell extends StatelessWidget {
  const _GoalTileShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.iconColor = RexUiTokens.accent,
  });

  final IconData icon;
  final Widget title;
  final Widget subtitle;
  final Widget? trailing;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return RexSurface(
      color: RexUiTokens.surface,
      borderColor: RexUiTokens.border.withValues(alpha: 0.78),
      radius: RexUiTokens.radiusMedium,
      padding: const EdgeInsets.all(RexUiTokens.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
            ),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
          const SizedBox(width: RexUiTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, subtitle],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: RexUiTokens.space8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RexSurface(
      radius: RexUiTokens.radiusSmall,
      color: RexUiTokens.danger.withValues(alpha: 0.1),
      borderColor: RexUiTokens.danger.withValues(alpha: 0.32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 17,
            color: RexUiTokens.danger,
          ),
          const SizedBox(width: RexUiTokens.space8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: RexUiTokens.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordSubtitle extends StatelessWidget {
  const _RecordSubtitle({required this.text, required this.chips});

  final String text;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: RexUiTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.trim().isNotEmpty)
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: RexUiTokens.textMuted,
              ),
            ),
          if (text.trim().isNotEmpty)
            const SizedBox(height: RexUiTokens.space8),
          Wrap(
            spacing: RexUiTokens.space8,
            runSpacing: RexUiTokens.space8,
            children: chips
                .where((chip) => chip.trim().isNotEmpty)
                .map((chip) => _MetaChip(label: chip))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: RexUiTokens.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
        border: Border.all(color: RexUiTokens.accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: RexUiTokens.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: RexUiTokens.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle? _tileTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleSmall?.copyWith(
    color: RexUiTokens.text,
    fontWeight: FontWeight.w700,
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: RexUiTokens.surfaceRaised.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(RexUiTokens.radiusSmall),
        border: Border.all(color: RexUiTokens.border.withValues(alpha: 0.58)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: RexUiTokens.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _InitialLoading extends StatelessWidget {
  const _InitialLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 320,
      child: Center(
        child: ClarityPathLoader(size: 52, label: 'Loading accountability'),
      ),
    );
  }
}

class _EmptyAccountabilityState extends StatelessWidget {
  const _EmptyAccountabilityState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 360,
      child: Center(
        child: RexSurface(
          color: RexUiTokens.surface,
          padding: const EdgeInsets.all(RexUiTokens.space20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 34,
                color: RexUiTokens.accent,
              ),
              const SizedBox(height: RexUiTokens.space12),
              Text(
                'No goals yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: RexUiTokens.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: RexUiTokens.space4),
              Text(
                'Plans, commitments, and helpful nudges will show up here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: RexUiTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RexSurface(
        color: RexUiTokens.danger.withValues(alpha: 0.12),
        borderColor: RexUiTokens.danger.withValues(alpha: 0.34),
        padding: const EdgeInsets.all(RexUiTokens.space12),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: RexUiTokens.danger,
              size: 18,
            ),
            const SizedBox(width: RexUiTokens.space8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: RexUiTokens.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _signalIcon(AccountabilitySignalType type) {
  switch (type) {
    case AccountabilitySignalType.ruleViolation:
      return Icons.rule_rounded;
    case AccountabilitySignalType.missedCommitment:
      return Icons.event_busy_rounded;
    case AccountabilitySignalType.planDrift:
      return Icons.route_rounded;
    case AccountabilitySignalType.repeatedPattern:
      return Icons.repeat_rounded;
    case AccountabilitySignalType.upcomingDeadline:
      return Icons.event_rounded;
    case AccountabilitySignalType.budgetRisk:
      return Icons.savings_rounded;
    case AccountabilitySignalType.positiveFollowThrough:
      return Icons.check_circle_rounded;
    case AccountabilitySignalType.unknown:
      return Icons.info_outline_rounded;
  }
}

Color _severityColor(AccountabilitySeverity severity) {
  switch (severity) {
    case AccountabilitySeverity.critical:
    case AccountabilitySeverity.high:
      return RexUiTokens.danger;
    case AccountabilitySeverity.medium:
      return RexUiTokens.accentStrong;
    case AccountabilitySeverity.low:
    case AccountabilitySeverity.info:
    case AccountabilitySeverity.unknown:
      return RexUiTokens.accent;
  }
}

String _sourceLabel(AccountabilitySourceRef source) {
  return source.displayLabel;
}

String _shortDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}
