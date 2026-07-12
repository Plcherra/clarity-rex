import 'package:flutter/material.dart';

import '../../theme/clarity_colors.dart';
import '../../widgets/clarity_card.dart';
import 'rex_ui_tokens.dart';

class OverviewStatChip extends StatelessWidget {
  const OverviewStatChip({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    this.emphasized = false,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final accent = theme.colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized
            ? accent.withValues(alpha: 0.12)
            : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
        border: Border.all(
          color: emphasized
              ? accent.withValues(alpha: 0.28)
              : colors.border.withValues(alpha: 0.85),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: emphasized ? accent : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: emphasized ? accent : colors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OverviewSectionCard extends StatelessWidget {
  const OverviewSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.count,
    this.actionLabel,
    this.onAction,
    this.highlighted = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return ClarityCard(
      highlighted: highlighted,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (count != null)
                        TextSpan(
                          text: '  $count',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: RexUiTokens.space12),
          child,
        ],
      ),
    );
  }
}

class OverviewLineItem extends StatelessWidget {
  const OverviewLineItem({
    super.key,
    required this.title,
    this.subtitle,
    this.showDivider = false,
  });

  final String title;
  final String? subtitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDivider) ...[
          Divider(
            height: 20,
            thickness: 1,
            color: colors.divider.withValues(alpha: 0.8),
          ),
        ],
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class OverviewEmptyState extends StatelessWidget {
  const OverviewEmptyState({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.clarityColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}

class OverviewLineList extends StatelessWidget {
  const OverviewLineList({
    super.key,
    required this.items,
    required this.emptyText,
  });

  final List<({String title, String? subtitle})> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return OverviewEmptyState(text: emptyText);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          OverviewLineItem(
            title: items[i].title,
            subtitle: items[i].subtitle,
            showDivider: i > 0,
          ),
      ],
    );
  }
}
