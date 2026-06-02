import 'package:flutter/material.dart';

import 'package:clarity/features/assistant/chat/domain/chat_message.dart';

class ChatMemoryCandidateCards extends StatelessWidget {
  const ChatMemoryCandidateCards({
    required this.candidates,
    this.onApprove,
    this.onReject,
    this.onApproveAll,
    this.onRejectAll,
    this.onEdit,
    super.key,
  });

  final List<MemoryCandidateCard> candidates;
  final ValueChanged<MemoryCandidateCard>? onApprove;
  final ValueChanged<MemoryCandidateCard>? onReject;
  final VoidCallback? onApproveAll;
  final VoidCallback? onRejectAll;
  final ValueChanged<MemoryCandidateCard>? onEdit;

  @override
  Widget build(BuildContext context) {
    final pendingCount = candidates
        .where((candidate) => candidate.isPending)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.fact_check_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              pendingCount > 0 ? 'Memory review' : 'Memory update',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (pendingCount > 1 && onApproveAll != null)
              TextButton.icon(
                onPressed: onApproveAll,
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Save eligible'),
              ),
            if (pendingCount > 1 && onRejectAll != null)
              TextButton.icon(
                onPressed: onRejectAll,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Do not save all'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final candidate in candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MemoryCandidateCard(
              candidate: candidate,
              onApprove: onApprove,
              onReject: onReject,
              onEdit: onEdit,
            ),
          ),
      ],
    );
  }
}

class _MemoryCandidateCard extends StatelessWidget {
  const _MemoryCandidateCard({
    required this.candidate,
    this.onApprove,
    this.onReject,
    this.onEdit,
  });

  final MemoryCandidateCard candidate;
  final ValueChanged<MemoryCandidateCard>? onApprove;
  final ValueChanged<MemoryCandidateCard>? onReject;
  final ValueChanged<MemoryCandidateCard>? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isHighRisk = candidate.isHighRisk;
    final verificationPassed = candidate.verificationPassed;
    final isProblem = candidate.isFailed || isHighRisk;
    final accent = isProblem ? scheme.error : scheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: candidate.isFailed
            ? scheme.errorContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProblem
              ? scheme.error.withValues(alpha: 0.46)
              : scheme.outlineVariant.withValues(alpha: 0.55),
        ),
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
                _MemoryChip(label: candidate.candidateTypeLabel),
                _MemoryChip(label: candidate.riskLabel, color: accent),
                _MemoryChip(label: candidate.statusLabel, color: accent),
                if (verificationPassed != null)
                  _MemoryChip(
                    label: verificationPassed ? 'verified' : 'failed',
                    color: verificationPassed ? scheme.primary : scheme.error,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              candidate.reviewTitleLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              candidate.previewLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (candidate.isCorrection &&
                (candidate.correctionOldValue != null ||
                    candidate.correctionNewValue != null))
              _CorrectionDetails(
                candidate: candidate,
                color: scheme.onSurfaceVariant,
              ),
            if (candidate.reasonLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                'Why Rex paused here',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                candidate.reasonLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 4),
            _MemoryReviewDetailRow(
              icon: Icons.task_alt_rounded,
              text: candidate.expectedActionLabel,
              color: scheme.onSurfaceVariant,
            ),
            if (candidate.sourceLabel != null)
              _MemoryReviewDetailRow(
                icon: Icons.chat_bubble_outline_rounded,
                text: candidate.sourceLabel!,
                color: scheme.onSurfaceVariant,
              ),
            _MemoryReviewDetailRow(
              icon: _statusIcon(candidate),
              text: candidate.statusDetail,
              color: isProblem ? scheme.error : scheme.onSurfaceVariant,
            ),
            if (candidate.verificationMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                candidate.verificationMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: verificationPassed == false
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
            if (candidate.canApprove || candidate.canReject)
              _MemoryCandidateActions(
                candidate: candidate,
                isHighRisk: isHighRisk,
                onApprove: onApprove,
                onReject: onReject,
                onEdit: onEdit,
              ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(MemoryCandidateCard candidate) {
    if (candidate.isPending) {
      return Icons.info_outline_rounded;
    }
    if (candidate.isApplied) {
      return Icons.check_circle_outline_rounded;
    }
    if (candidate.isRejected) {
      return Icons.block_rounded;
    }
    if (candidate.isFailed) {
      return Icons.error_outline_rounded;
    }
    return Icons.remove_circle_outline_rounded;
  }
}

class _CorrectionDetails extends StatelessWidget {
  const _CorrectionDetails({required this.candidate, required this.color});

  final MemoryCandidateCard candidate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (candidate.correctionOldValue != null)
          _MemoryReviewDetailRow(
            icon: Icons.history_rounded,
            text: 'May change: ${candidate.correctionOldValue}',
            color: color,
          ),
        if (candidate.correctionNewValue != null)
          _MemoryReviewDetailRow(
            icon: Icons.update_rounded,
            text: 'Replace with: ${candidate.correctionNewValue}',
            color: color,
          ),
      ],
    );
  }
}

class _MemoryCandidateActions extends StatelessWidget {
  const _MemoryCandidateActions({
    required this.candidate,
    required this.isHighRisk,
    this.onApprove,
    this.onReject,
    this.onEdit,
  });

  final MemoryCandidateCard candidate;
  final bool isHighRisk;
  final ValueChanged<MemoryCandidateCard>? onApprove;
  final ValueChanged<MemoryCandidateCard>? onReject;
  final ValueChanged<MemoryCandidateCard>? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (candidate.canApprove && onApprove != null)
            FilledButton.icon(
              onPressed: () => onApprove!(candidate),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text(isHighRisk ? 'Confirm save' : 'Save'),
            ),
          if (candidate.canReject && onReject != null)
            OutlinedButton.icon(
              onPressed: () => onReject!(candidate),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Do not save'),
            ),
          if (candidate.canApprove && onEdit != null)
            TextButton.icon(
              onPressed: () => onEdit!(candidate),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Edit first'),
            ),
        ],
      ),
    );
  }
}

class _MemoryReviewDetailRow extends StatelessWidget {
  const _MemoryReviewDetailRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                height: 1.3,
              ),
            ),
          ),
        ],
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
