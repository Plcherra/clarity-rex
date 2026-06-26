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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: isBusy ? null : onAddGoal,
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('Add goal'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: RexUiTokens.space8),
          Expanded(
            child: TextButton.icon(
              onPressed: isBusy ? null : onAddCommitment,
              icon: Icon(
                Icons.check_circle_outline_rounded,
                size: 16,
                color: colors.accent,
              ),
              label: Text(
                'Add commitment',
                style: TextStyle(color: colors.accent),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
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
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: RexUiTokens.space8),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RexUiTokens.space4),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: colors.textMuted,
                  size: 16,
                ),
                const SizedBox(width: RexUiTokens.space8),
                Expanded(
                  child: Text(
                    emptyText,
                    style: theme.textTheme.bodySmall?.copyWith(
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
  });

  final IconData icon;
  final Widget title;
  final Widget subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RexUiTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.accent, size: 18),
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

class _SimpleGoalDetails extends StatelessWidget {
  const _SimpleGoalDetails({
    required this.description,
    required this.deadline,
    required this.priority,
    required this.status,
  });

  final String description;
  final DateTime? deadline;
  final int priority;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final meta = <String>[
      if (deadline != null) 'By ${_shortDate(deadline!)}',
      _priorityLabel(priority),
      _statusLabel(status),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: RexUiTokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.trim().isNotEmpty)
            Text(
              description.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textMuted,
              ),
            ),
          if (description.trim().isNotEmpty)
            const SizedBox(height: RexUiTokens.space8),
          Text(
            meta.join(' · '),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
              Icon(Icons.flag_outlined, size: 28, color: colors.accent),
              const SizedBox(height: RexUiTokens.space8),
            ],
            Text(
              'No goals yet',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: RexUiTokens.space4),
            Text(
              'Add a goal or commitment above, or tell Rex in chat.',
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
    final colors = context.clarityColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RexSurface(
        color: colors.danger.withValues(alpha: 0.12),
        borderColor: colors.danger.withValues(alpha: 0.34),
        padding: const EdgeInsets.all(RexUiTokens.space12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colors.danger,
              size: 18,
            ),
            const SizedBox(width: RexUiTokens.space8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}

String _priorityLabel(int priority) {
  if (priority >= 5) {
    return 'High priority';
  }
  if (priority >= 4) {
    return 'Medium priority';
  }
  if (priority >= 3) {
    return 'Normal priority';
  }
  return 'Low priority';
}

String _statusLabel(String status) {
  final normalized = status.trim().toLowerCase().replaceAll('_', ' ');
  if (normalized.isEmpty) {
    return 'Open';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}
