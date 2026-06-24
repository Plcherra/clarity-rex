import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/ui_dependencies.dart';
import '../../../widgets/clarity_card.dart';

/// Floating panel for the unified CSV upload + AI categorization job.
class ImportJobProgressBanner extends StatelessWidget {
  const ImportJobProgressBanner({super.key, required this.controller});

  final ImportJobStatusController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = controller.importProgressTotal;
    final done = controller.importProgressCompleted;
    final pct = total > 0 ? ((done / total) * 100).round() : 0;
    final message = _importProgressDisplayMessage(
      controller.importProgressMessage,
      MediaQuery.sizeOf(context).width,
    );
    return ClarityCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.96),
      borderColor: cs.outline.withValues(alpha: 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$message $pct%',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total > 0 ? done / total : null,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

String _importProgressDisplayMessage(String rawMessage, double screenWidth) {
  final normalized = rawMessage
      .replaceFirst(RegExp(r'\s+\d+/\d+\s+batches\b'), '')
      .trim();
  if (screenWidth > 600) {
    return normalized;
  }
  final lower = normalized.toLowerCase();
  if (lower.startsWith('uploading') ||
      lower.startsWith('parsing') ||
      lower.startsWith('saving transactions')) {
    return 'Importing...';
  }
  if (lower.startsWith('categorizing')) {
    return 'Categorizing...';
  }
  if (lower.startsWith('applying categories')) {
    return 'Saving categories...';
  }
  if (lower.startsWith('ai failed')) {
    return 'Applying fallback categories...';
  }
  if (lower.startsWith('refreshing')) {
    return 'Refreshing...';
  }
  return normalized;
}

/// Banner while running, optional snack from import AI status state.
class ImportJobStatusHost extends StatefulWidget {
  const ImportJobStatusHost({
    super.key,
    required this.controller,
    required this.child,
    this.onManageCategories,
  });

  final ImportJobStatusController controller;
  final Widget child;
  final VoidCallback? onManageCategories;

  @override
  State<ImportJobStatusHost> createState() => _ImportJobStatusHostState();
}

class _ImportJobStatusHostState extends State<ImportJobStatusHost> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final msg = widget.controller.consumeImportSnackMessage();
          if (msg != null && msg.isNotEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
        });
        final showPersistentMessage =
            !widget.controller.importRunning &&
            widget.controller.persistentImportMessage != null;
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (widget.controller.importRunning)
              _BottomSafeImportOverlay(
                child: ImportJobProgressBanner(controller: widget.controller),
              ),
            if (showPersistentMessage)
              _BottomSafeImportOverlay(
                child: _PersistentImportMessageBanner(
                  controller: widget.controller,
                  onManageCategories: widget.onManageCategories,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BottomSafeImportOverlay extends StatelessWidget {
  const _BottomSafeImportOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PersistentImportMessageBanner extends StatelessWidget {
  const _PersistentImportMessageBanner({
    required this.controller,
    this.onManageCategories,
  });

  final ImportJobStatusController controller;
  final VoidCallback? onManageCategories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isError = controller.persistentImportMessageIsError;
    final background = isError
        ? cs.errorContainer
        : cs.tertiaryContainer.withValues(alpha: 0.9);
    final foreground = isError ? cs.onErrorContainer : cs.onTertiaryContainer;
    final summary = controller.persistentImportSummary;
    return ClarityCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      backgroundColor: background,
      borderColor: foreground.withValues(alpha: 0.18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                color: foreground,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary?.title ?? controller.persistentImportMessage ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: controller.dismissPersistentImportMessage,
                icon: Icon(Icons.close_rounded, color: foreground),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (summary == null) ...[
            const SizedBox(height: 2),
            Text(
              controller.persistentImportMessage ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            for (final line in summary.lines) ...[
              Text(
                line,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: foreground.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
            ],
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              if ((summary?.canRetry ?? false) ||
                  controller.persistentImportMessageCanRetry)
                TextButton.icon(
                  onPressed: controller.retryCategoryAssignment,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: foreground,
                    size: 18,
                  ),
                  label: Text('Retry', style: TextStyle(color: foreground)),
                ),
              if (summary?.canOpenCategoryManagement == true &&
                  onManageCategories != null)
                TextButton.icon(
                  onPressed: onManageCategories,
                  icon: Icon(
                    Icons.category_outlined,
                    color: foreground,
                    size: 18,
                  ),
                  label: Text(
                    'Categories',
                    style: TextStyle(color: foreground),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
