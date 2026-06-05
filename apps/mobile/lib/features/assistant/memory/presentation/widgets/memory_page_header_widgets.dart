import 'package:flutter/material.dart';

import 'package:clarity/features/assistant/memory/presentation/widgets/memory_quick_filter.dart';
import 'package:clarity/features/assistant/presentation/rex_surfaces.dart';
import 'package:clarity/features/assistant/presentation/rex_ui_tokens.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          style: theme.textTheme.bodyLarge?.copyWith(color: RexUiTokens.text),
          textInputAction: TextInputAction.search,
          cursorColor: RexUiTokens.accent,
          decoration: InputDecoration(
            hintText: 'Search what Rex knows',
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
            fillColor: RexUiTokens.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
              borderSide: const BorderSide(color: RexUiTokens.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
              borderSide: const BorderSide(color: RexUiTokens.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
              borderSide: const BorderSide(color: RexUiTokens.accent),
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
                backgroundColor: RexUiTokens.surface,
                selectedColor: RexUiTokens.accent,
                disabledColor: RexUiTokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RexUiTokens.radiusPill),
                  side: BorderSide(
                    color: selectedFilter == filter
                        ? RexUiTokens.accent
                        : RexUiTokens.border,
                  ),
                ),
                showCheckmark: false,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: selectedFilter == filter
                      ? RexUiTokens.background
                      : RexUiTokens.textMuted,
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

    return RexSurface(
      color: RexUiTokens.surface,
      borderColor: RexUiTokens.border,
      radius: RexUiTokens.radiusMedium,
      padding: const EdgeInsets.all(RexUiTokens.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.psychology_alt_outlined, color: RexUiTokens.accent),
          const SizedBox(width: RexUiTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What Rex knows',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: RexUiTokens.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: RexUiTokens.space4),
                Text(
                  'Saved details Rex can use later. Edit anything that changes.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: RexUiTokens.textMuted,
                  ),
                ),
              ],
            ),
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
      child: CircularProgressIndicator(
        color: RexUiTokens.accent,
        strokeWidth: 2.5,
      ),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RexUiTokens.space16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: RexUiTokens.textMuted, size: 28),
              const SizedBox(height: RexUiTokens.space8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: RexUiTokens.space4),
              Text(
                body,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: RexUiTokens.textMuted,
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
    return activeOnly ? 'Rex is still learning' : 'No saved information yet';
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
