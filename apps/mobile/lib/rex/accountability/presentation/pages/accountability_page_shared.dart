part of 'accountability_page.dart';

class _GoalActionBar extends StatelessWidget {
  const _GoalActionBar({
    required this.isBusy,
    required this.onAddGoal,
    required this.onAddCommitment,
  });

  final bool isBusy;
  final VoidCallback onAddGoal;
  final VoidCallback onAddCommitment;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return RexSurface(
      color: colors.surface.withValues(alpha: 0.66),
      radius: RexUiTokens.radiusLarge,
      padding: const EdgeInsets.all(RexUiTokens.space12),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: isBusy ? null : onAddCommitment,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Add commitment'),
            ),
          ),
          const SizedBox(width: RexUiTokens.space8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isBusy ? null : onAddGoal,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Add goal'),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final colors = context.clarityColors;

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
            color: colors.surface.withValues(alpha: 0.58),
            radius: RexUiTokens.radiusLarge,
            padding: const EdgeInsets.all(RexUiTokens.space16),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: colors.textMuted,
                  size: 18,
                ),
                const SizedBox(width: RexUiTokens.space8),
                Expanded(
                  child: Text(
                    emptyText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
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
    final colors = context.clarityColors;
    return RexSurface(
      color: colors.surface.withValues(alpha: 0.66),
      radius: RexUiTokens.radiusLarge,
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
    final colors = context.clarityColors;

    return RexSurface(
      radius: RexUiTokens.radiusSmall,
      color: colors.danger.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 17, color: colors.danger),
          const SizedBox(width: RexUiTokens.space8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.danger,
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
    final colors = context.clarityColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colors.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.textPrimary,
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
  final colors = context.clarityColors;
  return Theme.of(context).textTheme.titleSmall?.copyWith(
    color: colors.textPrimary,
    fontWeight: FontWeight.w700,
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(RexUiTokens.radiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.textSecondary,
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: RexUiTokens.space24),
      child: Center(child: ClarityPathLoader(size: 52, label: 'Loading goals')),
    );
  }
}

class _EmptyAccountabilityState extends StatelessWidget {
  const _EmptyAccountabilityState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).height < 650;
    final colors = context.clarityColors;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? RexUiTokens.space12 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Icon(Icons.flag_outlined, size: 34, color: colors.accent),
              const SizedBox(height: RexUiTokens.space12),
            ],
            Text(
              'No goals yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: RexUiTokens.space4),
            Text(
              'Plans, commitments, and helpful nudges will show up here.',
              textAlign: TextAlign.center,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.25,
              ),
            ),
          ],
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
