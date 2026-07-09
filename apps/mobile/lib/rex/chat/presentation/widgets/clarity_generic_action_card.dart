import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

/// Title/body confirm card for non-person durable write proposals.
class ClarityGenericActionCard extends StatefulWidget {
  const ClarityGenericActionCard({
    super.key,
    required this.action,
    this.onConfirm,
    this.onDismiss,
  });

  final ClarityActionCard action;
  final ValueChanged<ClarityActionCard>? onConfirm;
  final ValueChanged<ClarityActionCard>? onDismiss;

  @override
  State<ClarityGenericActionCard> createState() =>
      _ClarityGenericActionCardState();
}

class _ClarityGenericActionCardState extends State<ClarityGenericActionCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.action.title ?? '');
    _bodyController = TextEditingController(text: widget.action.body ?? '');
  }

  @override
  void didUpdateWidget(covariant ClarityGenericActionCard oldWidget) {
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
    final isDeleteAction =
        action.writeKind == 'delete' || action.action == 'delete_record';
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
                    isDeleteAction
                        ? Icons.delete_outline_rounded
                        : Icons.save_outlined,
                    size: 22,
                    color: isDeleteAction ? scheme.error : scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pendingProposalHeadline(action),
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
              if (financeActionHeadline(action) case final headline?) ...[
                Text(
                  headline,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
              ],
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
                  label: Text(isDeleteAction ? 'Delete' : l10n.commonConfirm),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: isDeleteAction ? scheme.error : null,
                    foregroundColor: isDeleteAction ? scheme.onError : null,
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
                  label: Text(isDeleteAction ? 'Keep it' : l10n.commonDismiss),
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

String pendingProposalHeadline(ClarityActionCard action) {
  if (action.writeKind == 'delete' || action.action == 'delete_record') {
    switch (action.deleteTable) {
      case 'plans':
      case 'plan_milestones':
        return 'Delete from Goals';
      case 'open_threads':
        return 'Delete open thread';
      default:
        return 'Delete permanently';
    }
  }
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

String? financeActionHeadline(ClarityActionCard action) {
  switch (action.action) {
    case 'update_transaction':
    case 'bulk_update_transaction_category':
    case 'create_transaction':
    case 'delete_transaction':
      return 'Change in Transactions';
    case 'create_budget':
    case 'update_budget':
    case 'delete_budget':
      return 'Change in Budgets';
    case 'create_category':
    case 'update_category':
    case 'delete_category':
      return 'Change in Categories';
    case 'create_account':
    case 'update_account':
    case 'delete_account':
      return 'Change in Accounts';
    case 'delete_import_batch':
      return 'Change in Imports';
    default:
      return null;
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
