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
    final selectedTextColor = theme.brightness == Brightness.dark
        ? Colors.black
        : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          style: theme.textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
          textInputAction: TextInputAction.search,
          cursorColor: colors.accent,
          decoration: InputDecoration(
            hintText: 'Search what Clarity knows',
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: colors.textMuted,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: controller.clear,
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    tooltip: 'Clear search',
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
                ),
                side: BorderSide.none,
                showCheckmark: false,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
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
    final colors = context.clarityColors;

    return Padding(
      padding: const EdgeInsets.only(top: RexUiTokens.space8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Active information only',
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
            ],
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
