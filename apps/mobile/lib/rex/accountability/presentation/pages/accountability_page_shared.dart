part of 'accountability_page.dart';

class _GoalActionBar extends StatelessWidget {
  const _GoalActionBar({
    required this.isBusy,
    required this.onAddGoal,
    required this.onAddOpenThread,
  });

  final bool isBusy;
  final VoidCallback onAddGoal;
  final VoidCallback onAddOpenThread;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    return Wrap(
      spacing: RexUiTokens.space4,
      runSpacing: RexUiTokens.space4,
      children: [
        TextButton.icon(
          onPressed: isBusy ? null : onAddGoal,
          icon: Icon(Icons.add_rounded, size: 16, color: colors.accent),
          label: Text(
            l10n.accountabilitySharedAddGoal,
            style: TextStyle(color: colors.accent),
          ),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
        TextButton.icon(
          onPressed: isBusy ? null : onAddOpenThread,
          icon: Icon(Icons.add_rounded, size: 16, color: colors.textSecondary),
          label: Text(
            l10n.accountabilitySharedAddOpenThread,
            style: TextStyle(color: colors.textSecondary),
          ),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.emptyText,
    required this.children,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: ClarityNativeLayout.active(context)
              ? ClarityNativeLayout.sectionLabel(context)
              : theme.textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
        ),
        const SizedBox(height: RexUiTokens.space4),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RexUiTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emptyText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                if (emptyActionLabel != null && onEmptyAction != null) ...[
                  const SizedBox(height: RexUiTokens.space4),
                  TextButton(
                    onPressed: onEmptyAction,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(emptyActionLabel!),
                  ),
                ],
              ],
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  const SizedBox(height: RexUiTokens.space4),
              ],
            ],
          ),
      ],
    );
  }
}

class _InitialLoading extends StatelessWidget {
  const _InitialLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RexUiTokens.space24),
      child: Center(
        child: ClarityPathLoader(
          size: 52,
          label: context.l10n.accountabilitySharedLoading,
        ),
      ),
    );
  }
}

class _EmptyAccountabilityState extends StatelessWidget {
  const _EmptyAccountabilityState({required this.onAddGoal});

  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).height < 650;
    final colors = context.clarityColors;
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: ClarityNativeLayout.active(context)
            ? ClarityNativeLayout.pagePadding(context)
            : EdgeInsets.all(compact ? RexUiTokens.space12 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Icon(Icons.flag_outlined, size: 28, color: colors.accent),
              const SizedBox(height: RexUiTokens.space8),
            ],
            Text(
              l10n.accountabilitySharedEmptyTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: RexUiTokens.space4),
            Text(
              l10n.accountabilitySharedEmptyBody,
              textAlign: TextAlign.center,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: RexUiTokens.space8),
            TextButton(
              onPressed: onAddGoal,
              child: Text(l10n.accountabilitySharedAddFirstGoal),
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
        padding: ClarityNativeLayout.active(context)
            ? ClarityNativeLayout.cardPadding(context)
            : const EdgeInsets.all(RexUiTokens.space12),
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

String _dueDateLabel(AppLocalizations l10n, DateTime dateTime) {
  return l10n.commonDueDateValue(_shortDate(dateTime));
}

class _GoalFormResult {
  const _GoalFormResult({required this.primary, required this.detail});

  final String primary;
  final String detail;
}

class _GoalFormDialog extends StatefulWidget {
  const _GoalFormDialog({
    required this.title,
    required this.primaryLabel,
    required this.detailLabel,
    required this.primaryHint,
    required this.detailHint,
    this.initialPrimary = '',
    this.initialDetail = '',
  });

  final String title;
  final String primaryLabel;
  final String detailLabel;
  final String primaryHint;
  final String detailHint;
  final String initialPrimary;
  final String initialDetail;

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  late final TextEditingController _primaryController;
  late final TextEditingController _detailController;

  @override
  void initState() {
    super.initState();
    _primaryController = TextEditingController(text: widget.initialPrimary);
    _detailController = TextEditingController(text: widget.initialDetail);
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  void _submit() {
    final primary = _primaryController.text.trim();
    if (primary.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _GoalFormResult(primary: primary, detail: _detailController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _primaryController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: widget.primaryLabel,
              hintText: widget.primaryHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: widget.detailLabel,
              hintText: widget.detailHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.commonSave)),
      ],
    );
  }
}
