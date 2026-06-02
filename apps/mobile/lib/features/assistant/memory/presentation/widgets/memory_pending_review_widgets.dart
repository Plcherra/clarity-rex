import 'package:flutter/material.dart';

import 'package:clarity/features/assistant/memory/data/memory_models.dart';
import 'package:clarity/features/assistant/memory/presentation/widgets/memory_meta_chip.dart';

class PendingReviewHeader extends StatelessWidget {
  const PendingReviewHeader({required this.pendingCount, super.key});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.fact_check_outlined, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pendingCount == 0
                        ? 'No memory review needed'
                        : '$pendingCount item${pendingCount == 1 ? '' : 's'} to review before saving',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'These are not part of what Rex knows yet. Save only the items Rex should remember.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PendingCandidateList extends StatelessWidget {
  const PendingCandidateList({
    required this.candidates,
    required this.isSaving,
    required this.onApprove,
    required this.onEdit,
    required this.onReject,
    super.key,
  });

  final List<PendingMemoryCandidateItem> candidates;
  final bool isSaving;
  final ValueChanged<PendingMemoryCandidateItem> onApprove;
  final ValueChanged<PendingMemoryCandidateItem> onEdit;
  final ValueChanged<PendingMemoryCandidateItem> onReject;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: candidates.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final candidate = candidates[index];
        return _PendingCandidateTile(
          candidate: candidate,
          isSaving: isSaving,
          onApprove: () => onApprove(candidate),
          onEdit: () => onEdit(candidate),
          onReject: () => onReject(candidate),
        );
      },
    );
  }
}

class _PendingCandidateTile extends StatelessWidget {
  const _PendingCandidateTile({
    required this.candidate,
    required this.isSaving,
    required this.onApprove,
    required this.onEdit,
    required this.onReject,
  });

  final PendingMemoryCandidateItem candidate;
  final bool isSaving;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = candidate.isHighRisk ? scheme.error : scheme.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.14),
        foregroundColor: accent,
        child: Icon(
          candidate.isHighRisk
              ? Icons.warning_amber_rounded
              : Icons.fact_check_outlined,
          size: 20,
        ),
      ),
      title: Text(
        candidate.reviewTitleLabel,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candidate.previewLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (candidate.isCorrection &&
                (candidate.correctionOldValue != null ||
                    candidate.correctionNewValue != null)) ...[
              if (candidate.correctionOldValue != null)
                _MemoryReviewInfoRow(
                  icon: Icons.history_rounded,
                  text: 'May change: ${candidate.correctionOldValue}',
                  color: scheme.onSurfaceVariant,
                ),
              if (candidate.correctionNewValue != null)
                _MemoryReviewInfoRow(
                  icon: Icons.update_rounded,
                  text: 'Replace with: ${candidate.correctionNewValue}',
                  color: scheme.onSurfaceVariant,
                ),
              const SizedBox(height: 8),
            ],
            if (candidate.reason?.trim().isNotEmpty == true) ...[
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                MemoryMetaChip(label: candidate.candidateTypeLabel),
                MemoryMetaChip(label: candidate.riskLabel),
                MemoryMetaChip(label: candidate.statusLabel),
              ],
            ),
            const SizedBox(height: 8),
            _MemoryReviewInfoRow(
              icon: Icons.task_alt_rounded,
              text: candidate.expectedActionLabel,
              color: scheme.onSurfaceVariant,
            ),
            if (candidate.sourceLabel != null)
              _MemoryReviewInfoRow(
                icon: Icons.chat_bubble_outline_rounded,
                text: candidate.sourceLabel!,
                color: scheme.onSurfaceVariant,
              ),
            _MemoryReviewInfoRow(
              icon: candidate.isHighRisk
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline_rounded,
              text: candidate.statusDetail,
              color: candidate.isHighRisk
                  ? scheme.error
                  : scheme.onSurfaceVariant,
            ),
            if (candidate.verificationMessage != null)
              _MemoryReviewInfoRow(
                icon: candidate.verificationPassed == false
                    ? Icons.error_outline_rounded
                    : Icons.verified_outlined,
                text: candidate.verificationMessage!,
                color: candidate.verificationPassed == false
                    ? scheme.error
                    : scheme.onSurfaceVariant,
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: isSaving ? null : onApprove,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(candidate.isHighRisk ? 'Confirm save' : 'Save'),
                ),
                TextButton.icon(
                  onPressed: isSaving ? null : onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit first'),
                ),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onReject,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Do not save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryReviewInfoRow extends StatelessWidget {
  const _MemoryReviewInfoRow({
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
          Icon(icon, size: 16, color: color),
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

class PendingReviewEmptyState extends StatelessWidget {
  const PendingReviewEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt_rounded,
              color: scheme.onSurfaceVariant,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              'No pending memory review',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'When Rex notices something worth remembering, it will wait for your approval here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemoryFilteredEmptyState extends StatelessWidget {
  const MemoryFilteredEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: scheme.onSurfaceVariant,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text('No matching memories', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Try a different search or choose another memory filter.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
