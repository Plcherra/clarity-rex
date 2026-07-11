import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_quick_filter.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

class MemorySearchAndFilters extends StatelessWidget {
  const MemorySearchAndFilters({
    required this.controller,
    required this.selectedFilter,
    required this.onFilterSelected,
    super.key,
  });

  final TextEditingController controller;
  final MemoryQuickFilter selectedFilter;
  final ValueChanged<MemoryQuickFilter>? onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final selectedTextColor = theme.brightness == Brightness.dark
        ? Colors.black
        : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textPrimary),
          textInputAction: TextInputAction.search,
          cursorColor: colors.accent,
          decoration: InputDecoration(
            hintText: l10n.memoryHeaderSearchHint,
            hintStyle: theme.textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: colors.textSecondary,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: controller.clear,
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    tooltip: l10n.memoryHeaderClearSearchTooltip,
                  ),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
              borderSide: BorderSide(color: colors.borderActive, width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: RexUiTokens.space8,
              vertical: RexUiTokens.space4,
            ),
            isDense: true,
          ),
        ),
        const SizedBox(height: RexUiTokens.space8),
        Wrap(
          spacing: RexUiTokens.space8,
          runSpacing: RexUiTokens.space4,
          children: [
            for (final filter in MemoryQuickFilter.values)
              ChoiceChip(
                label: Text(filter.label(l10n)),
                selected: selectedFilter == filter,
                onSelected: onFilterSelected == null
                    ? null
                    : (_) => onFilterSelected!(filter),
                backgroundColor: colors.surfaceElevated.withValues(alpha: 0.72),
                selectedColor: colors.accent,
                disabledColor: colors.surface,
                visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
                ),
                side: BorderSide.none,
                showCheckmark: false,
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  color: selectedFilter == filter
                      ? selectedTextColor
                      : colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class SavedMemoryHeader extends StatelessWidget {
  const SavedMemoryHeader({
    super.key,
    this.onCreate,
    this.createEnabled = true,
  });

  final VoidCallback? onCreate;
  final bool createEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: RexUiTokens.space4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.memoryHeaderSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onCreate != null)
            IconButton(
              onPressed: createEnabled ? onCreate : null,
              icon: const Icon(Icons.add_rounded),
              tooltip: l10n.memoryCreateAddTooltip,
            ),
        ],
      ),
    );
  }
}

class ActiveMemoryToggle extends StatelessWidget {
  const ActiveMemoryToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Padding(
      padding: const EdgeInsets.only(top: RexUiTokens.space8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.memoryHeaderActiveOnly,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: theme.brightness == Brightness.dark
                ? Colors.black
                : Colors.white,
            activeTrackColor: colors.accent,
            inactiveThumbColor: colors.textMuted,
            inactiveTrackColor: colors.surfaceElevated,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class MemoryErrorBanner extends StatelessWidget {
  const MemoryErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return RexSurface(
      color: colors.danger.withValues(alpha: 0.10),
      radius: RexUiTokens.radiusMedium,
      padding: const EdgeInsets.all(RexUiTokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.danger, size: 20),
          const SizedBox(width: RexUiTokens.space8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class MemoryLoadingState extends StatelessWidget {
  const MemoryLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClarityPathLoader(size: 52, label: context.l10n.memoryHeaderLoading),
    );
  }
}

class _EmptyMemoryShell extends StatelessWidget {
  const _EmptyMemoryShell({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final compact = MediaQuery.sizeOf(context).height < 650;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          compact ? RexUiTokens.space8 : RexUiTokens.space16,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                Icon(icon, color: colors.accent, size: 28),
                const SizedBox(height: RexUiTokens.space12),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(
                height: compact ? RexUiTokens.space2 : RexUiTokens.space4,
              ),
              Text(
                body,
                textAlign: TextAlign.center,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.25,
                  fontSize: 14,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: RexUiTokens.space12),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MemoryEmptyState extends StatelessWidget {
  const MemoryEmptyState({
    required this.activeOnly,
    this.onCreate,
    super.key,
  });

  final bool activeOnly;
  final VoidCallback? onCreate;

  String _emptyTitle(AppLocalizations l10n) {
    return activeOnly
        ? l10n.memoryHeaderEmptyActiveTitle
        : l10n.memoryHeaderEmptyTitle;
  }

  String _emptyBody(AppLocalizations l10n) {
    return activeOnly
        ? l10n.memoryHeaderEmptyActiveBody
        : l10n.memoryHeaderEmptyBody;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _EmptyMemoryShell(
      icon: Icons.psychology_alt_outlined,
      title: _emptyTitle(l10n),
      body: _emptyBody(l10n),
      actionLabel: onCreate == null ? null : l10n.memoryHeaderEmptyAddAction,
      onAction: onCreate,
    );
  }
}

class MemoryFilteredEmptyState extends StatelessWidget {
  const MemoryFilteredEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _EmptyMemoryShell(
      icon: Icons.search_off_rounded,
      title: l10n.memoryHeaderNoMatchingTitle,
      body: l10n.memoryHeaderNoMatchingBody,
    );
  }
}
