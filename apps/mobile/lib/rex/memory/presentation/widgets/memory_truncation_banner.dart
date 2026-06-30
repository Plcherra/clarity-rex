import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';

class MemoryTruncationBanner extends StatelessWidget {
  const MemoryTruncationBanner({
    required this.canLoadMore,
    this.onLoadMore,
    super.key,
  });

  final bool canLoadMore;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.clarityColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        RexUiTokens.space8,
        RexUiTokens.space16,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(RexUiTokens.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.memoryOverviewTruncated,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (canLoadMore && onLoadMore != null) ...[
                const SizedBox(height: RexUiTokens.space8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onLoadMore,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.memoryOverviewLoadMore),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
