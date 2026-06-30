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

    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.chatBubbleClarityAction,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
        : scheme.primary.withValues(alpha: 0.38);
    final canEditTitle = action.editableFields.contains('title');
    final canEditBody = action.editableFields.contains('body');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSoft.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 8),
            Text(
              action.confirmationText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (canEditTitle) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                enabled: !action.isApplying,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  isDense: true,
                ),
              ),
            ],
            if (canEditBody) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _bodyController,
                enabled: !action.isApplying,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  isDense: true,
                ),
              ),
            ],
            if (action.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                action.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  height: 1.3,
                ),
              ),
            ],
            if (action.isApplied) ...[
              const SizedBox(height: 6),
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if ((action.canConfirm || action.isApplying) &&
                      widget.onConfirm != null)
                    FilledButton.icon(
                      onPressed: action.isApplying
                          ? null
                          : () => widget.onConfirm!(_confirmedAction()),
                      icon: action.isApplying
                          ? const ClarityInlineLoader(size: 16, strokeWidth: 2)
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(l10n.commonConfirm),
                    ),
                  if (action.canDismiss && widget.onDismiss != null)
                    OutlinedButton.icon(
                      onPressed: action.isApplying
                          ? null
                          : () => widget.onDismiss!(action),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(l10n.commonDismiss),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
  for (final message in messages.toList().reversed) {
    if (message.role != ChatMessageRole.assistant) {
      continue;
    }
    final pending = message.clarityActions
        .where((action) => action.status == 'pending')
        .toList(growable: false);
    if (pending.isNotEmpty) {
      return pending;
    }
  }
  return const [];
}
