import 'package:flutter/material.dart';

import 'package:clarity/core/layout/clarity_breakpoints.dart';
import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/memory_l10n.dart';
import 'package:clarity/rex/memory/presentation/widgets/entity_memory_tile.dart';
import 'package:clarity/rex/memory/presentation/widgets/saved_memory_results.dart';
import 'package:clarity/rex/memory/presentation/widgets/saved_memory_tiles.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';

class SavedMemoryGroupList extends StatelessWidget {
  const SavedMemoryGroupList({
    required this.saved,
    required this.eventPreviewsFor,
    required this.milestonePreviewsFor,
    required this.onEditMemory,
    required this.onArchiveMemory,
    required this.onEditPerson,
    required this.onEditEntity,
    required this.onEditRule,
    required this.onEditPlan,
    required this.onAddPlanMilestone,
    required this.onEditPlanMilestone,
    required this.onArchiveStructuredMemory,
    super.key,
  });

  final SavedMemoryResults saved;
  final List<EntityEventItem> Function(String entityId) eventPreviewsFor;
  final List<PlanMilestoneMemoryItem> Function(String planId)
      milestonePreviewsFor;
  final ValueChanged<MemoryItem> onEditMemory;
  final ValueChanged<MemoryItem> onArchiveMemory;
  final ValueChanged<PersonMemoryItem> onEditPerson;
  final ValueChanged<EntityMemoryItem> onEditEntity;
  final ValueChanged<RuleMemoryItem> onEditRule;
  final ValueChanged<PlanMemoryItem> onEditPlan;
  final ValueChanged<PlanMemoryItem> onAddPlanMilestone;
  final void Function(PlanMemoryItem plan, PlanMilestoneMemoryItem milestone)
      onEditPlanMilestone;
  final void Function(StructuredMemoryKind kind, String id, String label)
  onArchiveStructuredMemory;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wide = isClarityWideLayout(context);
    final children = <Widget>[];

    void addGroup(MemoryGroup group, List<Widget> tiles) {
      if (tiles.isEmpty) {
        return;
      }
      children.add(_MemoryGroupHeader(
        label: group.localizedLabel(l10n),
      ));
      if (wide) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RexUiTokens.space16,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final tile in tiles)
                      SizedBox(width: tileWidth, child: tile),
                  ],
                );
              },
            ),
          ),
        );
      } else {
        children.addAll(tiles);
      }
    }

    addGroup(MemoryGroup.people, [
      ...saved.people.map(
        (person) => PersonMemoryTile(
          person: person,
          eventPreviews: eventPreviewsFor(person.id),
          onEdit: () => onEditPerson(person),
          onDeactivate: person.active
              ? () => onArchiveStructuredMemory(
                  StructuredMemoryKind.person,
                  person.id,
                  l10n.commonPerson,
                )
              : null,
        ),
      ),
      ...saved.peopleMemories.map(_memoryTile),
    ]);
    addGroup(
      MemoryGroup.facts,
      saved.facts.map(_memoryTile).toList(growable: false),
    );
    addGroup(
      MemoryGroup.preferences,
      saved.preferences.map(_memoryTile).toList(growable: false),
    );
    addGroup(MemoryGroup.places, [
      ...saved.placeEntities.map(
        (entity) => EntityMemoryTile(
          entity: entity,
          eventPreviews: eventPreviewsFor(entity.id),
          onEdit: () => onEditEntity(entity),
          onDeactivate: entity.active
              ? () => onArchiveStructuredMemory(
                  StructuredMemoryKind.entity,
                  entity.id,
                  entityTypeLabel(l10n, entity.entityType),
                )
              : null,
        ),
      ),
      ...saved.places.map(_memoryTile),
    ]);
    // Goals/plans live on the Goals tab only — not in Knows.
    addGroup(
      MemoryGroup.rules,
      saved.rules
          .map(
            (rule) => RuleMemoryTile(
              rule: rule,
              onEdit: () => onEditRule(rule),
              onDeactivate: rule.active
                  ? () => onArchiveStructuredMemory(
                      StructuredMemoryKind.rule,
                      rule.id,
                      'rule',
                    )
                  : null,
            ),
          )
          .toList(growable: false),
    );
    addGroup(
      MemoryGroup.events,
      saved.events.map(_memoryTile).toList(growable: false),
    );
    addGroup(MemoryGroup.other, [
      ...saved.otherEntities.map(
        (entity) => EntityMemoryTile(
          entity: entity,
          eventPreviews: eventPreviewsFor(entity.id),
          onEdit: () => onEditEntity(entity),
          onDeactivate: entity.active
              ? () => onArchiveStructuredMemory(
                  StructuredMemoryKind.entity,
                  entity.id,
                  entityTypeLabel(l10n, entity.entityType),
                )
              : null,
        ),
      ),
      ...saved.otherMemories.map(_memoryTile),
    ]);

    return SliverList.list(children: children);
  }

  Widget _memoryTile(MemoryItem memory) {
    return MemoryTile(
      memory: memory,
      onEdit: () => onEditMemory(memory),
      onDeactivate: memory.active ? () => onArchiveMemory(memory) : null,
    );
  }
}

class _MemoryGroupHeader extends StatelessWidget {
  const _MemoryGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        RexUiTokens.space24,
        RexUiTokens.space16,
        RexUiTokens.space8,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
