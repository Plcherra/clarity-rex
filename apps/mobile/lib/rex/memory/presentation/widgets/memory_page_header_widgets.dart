import 'package:flutter/material.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          style: theme.textTheme.bodyLarge?.copyWith(color: RexUiTokens.text),
          textInputAction: TextInputAction.search,
          cursorColor: RexUiTokens.accent,
          decoration: InputDecoration(
            hintText: 'Search what Clarity knows',
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: RexUiTokens.textSubtle,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: RexUiTokens.textMuted,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: controller.clear,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: RexUiTokens.textMuted,
                    ),
                    tooltip: 'Clear search',
                  ),
            filled: true,
            fillColor: colors.surface.withValues(alpha: 0.86),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
              borderSide: BorderSide(color: colors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
              borderSide: BorderSide(color: colors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
              borderSide: BorderSide(color: colors.borderActive),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: RexUiTokens.space16,
              vertical: RexUiTokens.space16,
            ),
          ),
        ),
        const SizedBox(height: RexUiTokens.space12),
        Wrap(
          spacing: RexUiTokens.space8,
          runSpacing: RexUiTokens.space8,
          children: [
            for (final filter in MemoryQuickFilter.values)
              ChoiceChip(
                label: Text(filter.label),
                selected: selectedFilter == filter,
                onSelected: onFilterSelected == null
                    ? null
                    : (_) => onFilterSelected!(filter),
                backgroundColor: colors.surfaceElevated.withValues(alpha: 0.72),
                selectedColor: colors.accent,
                disabledColor: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
                  side: BorderSide(
                    color: selectedFilter == filter
                        ? colors.accent
                        : colors.divider,
                  ),
                ),
                showCheckmark: false,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: selectedFilter == filter
                      ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white)
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
  const SavedMemoryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: RexUiTokens.space4),
      child: Text(
        'What Clarity knows',
        style: theme.textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
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

    return Padding(
      padding: const EdgeInsets.only(top: RexUiTokens.space8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Active information only',
              style: theme.textTheme.titleSmall?.copyWith(
                color: RexUiTokens.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: RexUiTokens.background,
            activeTrackColor: RexUiTokens.accent,
            inactiveThumbColor: RexUiTokens.textMuted,
            inactiveTrackColor: RexUiTokens.surfaceRaised,
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

    return RexSurface(
      color: RexUiTokens.danger.withValues(alpha: 0.1),
      borderColor: RexUiTokens.danger.withValues(alpha: 0.38),
      radius: RexUiTokens.radiusMedium,
      padding: const EdgeInsets.all(RexUiTokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: RexUiTokens.danger,
            size: 20,
          ),
          const SizedBox(width: RexUiTokens.space8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: RexUiTokens.danger,
              ),
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
    return const Center(
      child: ClarityPathLoader(size: 52, label: 'Loading memory'),
    );
  }
}

class _EmptyMemoryShell extends StatelessWidget {
  const _EmptyMemoryShell({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).height < 650;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          compact ? RexUiTokens.space8 : RexUiTokens.space16,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: RexSurface(
            padding: EdgeInsets.all(
              compact ? RexUiTokens.space12 : RexUiTokens.space20,
            ),
            color: RexUiTokens.surface.withValues(alpha: 0.78),
            borderColor: RexUiTokens.border.withValues(alpha: 0.65),
            radius: RexUiTokens.radiusLarge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: RexUiTokens.accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(
                        RexUiTokens.radiusLarge,
                      ),
                    ),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: Icon(icon, color: RexUiTokens.accent, size: 27),
                    ),
                  ),
                  const SizedBox(height: RexUiTokens.space12),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: RexUiTokens.text,
                    fontWeight: FontWeight.w900,
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
                    color: RexUiTokens.textMuted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MemoryEmptyState extends StatelessWidget {
  const MemoryEmptyState({required this.activeOnly, super.key});

  final bool activeOnly;

  String get _emptyTitle {
    return activeOnly
        ? 'Clarity is still learning'
        : 'No saved information yet';
  }

  String get _emptyBody {
    return 'Facts saved from chat or voice will appear here.';
  }

  @override
  Widget build(BuildContext context) {
    return _EmptyMemoryShell(
      icon: Icons.psychology_alt_outlined,
      title: _emptyTitle,
      body: _emptyBody,
    );
  }
}

class MemoryFilteredEmptyState extends StatelessWidget {
  const MemoryFilteredEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const _EmptyMemoryShell(
      icon: Icons.search_off_rounded,
      title: 'No matching information',
      body: 'Try another search or filter.',
    );
  }
}
