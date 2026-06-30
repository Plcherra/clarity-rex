import 'package:flutter/material.dart';

class BudgetCategoryRowTile extends StatelessWidget {
  const BudgetCategoryRowTile({
    super.key,
    required this.displayLabel,
    required this.controller,
    required this.focusNode,
    required this.indicatorColor,
    required this.statusText,
    required this.statusColor,
    this.onValueChanged,
  });

  final String displayLabel;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color indicatorColor;
  final String statusText;
  final Color statusColor;
  final ValueChanged<String>? onValueChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                height: 32,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onValueChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  textInputAction: TextInputAction.done,
                  onEditingComplete: focusNode.unfocus,
                  onSubmitted: (_) => focusNode.unfocus(),
                  scrollPadding: EdgeInsets.only(bottom: keyboardInset + 120),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    hintText: '—',
                    prefixText: r'$',
                    prefixStyle: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.46),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(
                        color: cs.outline.withValues(alpha: 0.20),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(
                        color: cs.outline.withValues(alpha: 0.20),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Text(
              statusText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
