import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

/// Confirm/dismiss cards for pending Clarity write proposals.
class ClarityActionCardsStrip extends StatelessWidget {
  const ClarityActionCardsStrip({
    super.key,
    required this.actions,
    this.onConfirm,
    this.onDismiss,
  });

  final List<ClarityActionCard> actions;
  final ValueChanged<ClarityActionCard>? onConfirm;
  final ValueChanged<ClarityActionCard>? onDismiss;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ClarityActionCard(
              action: action,
              onConfirm: onConfirm,
              onDismiss: onDismiss,
            ),
          ),
      ],
    );
  }
}

class _ClarityActionCard extends StatefulWidget {
  const _ClarityActionCard({
    required this.action,
    this.onConfirm,
    this.onDismiss,
  });

  final ClarityActionCard action;
  final ValueChanged<ClarityActionCard>? onConfirm;
  final ValueChanged<ClarityActionCard>? onDismiss;

  @override
  State<_ClarityActionCard> createState() => _ClarityActionCardState();
}

class _ClarityActionCardState extends State<_ClarityActionCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.action.title ?? '');
    _bodyController = TextEditingController(text: widget.action.body ?? '');
  }

  @override
  void didUpdateWidget(covariant _ClarityActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action.id != widget.action.id) {
      _titleController.text = widget.action.title ?? '';
      _bodyController.text = widget.action.body ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  ClarityActionCard _confirmedAction() {
    final action = widget.action;
    if (!action.hasEditableFields) {
      return action;
    }
    return action.copyWith(
      title: _titleController.text.trim().isEmpty
          ? action.title
          : _titleController.text.trim(),
      body: _bodyController.text.trim().isEmpty
          ? action.body
          : _bodyController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final isHighRisk = action.riskLevel == 'high';
    final borderColor = action.isFailed || isHighRisk
        ? scheme.error.withValues(alpha: 0.46)
        : scheme.primary.withValues(alpha: 0.42);
    final canEditTitle = action.editableFields.contains('title');
    final canEditBody = action.editableFields.contains('body');
    final isPendingProposal =
        action.isPending && action.hasEditableFields && !action.isApplying;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isPendingProposal) ...[
              Row(
                children: [
                  Icon(
                    Icons.save_outlined,
                    size: 22,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pendingProposalHeadline(action),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MemoryChip(label: action.actionLabel),
                  _MemoryChip(
                    label: action.riskLabel,
                    color: isHighRisk ? scheme.error : scheme.primary,
                  ),
                  _MemoryChip(
                    label: action.statusLabel,
                    color: action.isFailed ? scheme.error : scheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                action.confirmationText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
            if (canEditTitle) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _titleController,
                enabled: !action.isApplying,
                style: theme.textTheme.titleSmall,
                decoration: InputDecoration(
                  labelText: 'Title',
                  filled: true,
                  fillColor: colors.surfaceSoft.withValues(alpha: 0.72),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            if (canEditBody) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                enabled: !action.isApplying,
                minLines: 3,
                maxLines: 5,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Details (optional)',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: colors.surfaceSoft.withValues(alpha: 0.72),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            if (action.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                action.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  height: 1.3,
                ),
              ),
            ],
            if (action.isApplied) ...[
              const SizedBox(height: 8),
              Text(
                l10n.commonRecordsApplied(action.result.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
            if (action.canConfirm ||
                action.canDismiss ||
                action.isApplying) ...[
              const SizedBox(height: 16),
              if ((action.canConfirm || action.isApplying) &&
                  widget.onConfirm != null)
                FilledButton.icon(
                  onPressed: action.isApplying
                      ? null
                      : () => widget.onConfirm!(_confirmedAction()),
                  icon: action.isApplying
                      ? const ClarityInlineLoader(size: 18, strokeWidth: 2)
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(l10n.commonConfirm),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (action.canDismiss && widget.onDismiss != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: action.isApplying
                      ? null
                      : () => widget.onDismiss!(action),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  label: Text(l10n.commonDismiss),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

String _pendingProposalHeadline(ClarityActionCard action) {
  switch (action.writeKind) {
    case 'open_thread':
      return 'Track in Goals';
    case 'plan':
    case 'milestone':
      return 'Save to Goals';
    case 'memory':
    default:
      return 'Save to Clarity Knows';
  }
}

class _MemoryChip extends StatelessWidget {
  const _MemoryChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chipColor = color ?? scheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: chipColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

List<ClarityActionCard> pendingClarityActions(Iterable<ChatMessage> messages) {
  final seenIds = <String>{};
  for (final message in messages.toList().reversed) {
    if (message.role != ChatMessageRole.assistant) {
      continue;
    }
    final pending = <ClarityActionCard>[];
    for (final action in message.clarityActions) {
      if (action.status != 'pending') {
        continue;
      }
      if (action.id.isEmpty || seenIds.add(action.id)) {
        pending.add(action);
      }
    }
    if (pending.isNotEmpty) {
      return List.unmodifiable(pending);
    }
  }
  return const [];
}

Future<void> showClarityActionConfirmationDialog(
  BuildContext context, {
  required ClarityActionCard action,
  ValueChanged<ClarityActionCard>? onConfirm,
  ValueChanged<ClarityActionCard>? onDismiss,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: action.canDismiss,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _ClarityActionCard(
              action: action,
              onConfirm: onConfirm == null
                  ? null
                  : (confirmed) {
                      Navigator.of(dialogContext).pop();
                      onConfirm(confirmed);
                    },
              onDismiss: onDismiss == null
                  ? null
                  : (dismissed) {
                      Navigator.of(dialogContext).pop();
                      onDismiss(dismissed);
                    },
            ),
          ),
        ),
      );
    },
  );
}
