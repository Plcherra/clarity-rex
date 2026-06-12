import 'package:flutter/material.dart';

import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/widgets/saved_memory_results.dart';
import 'package:clarity/rex/memory/presentation/widgets/saved_memory_tiles.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';

class SavedMemoryGroupList extends StatelessWidget {
  const SavedMemoryGroupList({
    required this.saved,
    required this.onEditMemory,
    required this.onArchiveMemory,
    required this.onEditPerson,
    required this.onEditRule,
    required this.onEditPlan,
    required this.onEditCommitment,
    required this.onArchiveStructuredMemory,
    super.key,
  });

  final SavedMemoryResults saved;
  final ValueChanged<MemoryItem> onEditMemory;
  final ValueChanged<MemoryItem> onArchiveMemory;
  final ValueChanged<PersonMemoryItem> onEditPerson;
  final ValueChanged<RuleMemoryItem> onEditRule;
  final ValueChanged<PlanMemoryItem> onEditPlan;
  final ValueChanged<CommitmentMemoryItem> onEditCommitment;
  final void Function(MemoryLayer layer, String id, String label)
  onArchiveStructuredMemory;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    void addGroup(MemoryGroup group, List<Widget> tiles) {
      if (tiles.isEmpty) {
        return;
      }
      children.add(_MemoryGroupHeader(group: group));
      for (final tile in tiles) {
        children.add(tile);
      }
    }

    addGroup(
      MemoryGroup.identity,
      saved.identity.map(_memoryTile).toList(growable: false),
    );
    addGroup(
      MemoryGroup.preferences,
      saved.preferences.map(_memoryTile).toList(growable: false),
    );
    addGroup(
      MemoryGroup.peoplePlaces,
      saved.people
          .map(
            (person) => PersonMemoryTile(
              person: person,
              onEdit: () => onEditPerson(person),
              onDeactivate: person.active
                  ? () => onArchiveStructuredMemory(
                      MemoryLayer.people,
                      person.id,
                      'person',
                    )
                  : null,
            ),
          )
          .toList(growable: false),
    );
    addGroup(MemoryGroup.plans, [
      ...saved.plans.map(
        (plan) => PlanMemoryTile(
          plan: plan,
          onEdit: () => onEditPlan(plan),
          onDeactivate: plan.active
              ? () => onArchiveStructuredMemory(
                  MemoryLayer.plans,
                  plan.id,
                  'plan',
                )
              : null,
        ),
      ),
      ...saved.commitments.map(
        (commitment) => CommitmentMemoryTile(
          commitment: commitment,
          onEdit: () => onEditCommitment(commitment),
          onDeactivate: commitment.active
              ? () => onArchiveStructuredMemory(
                  MemoryLayer.commitments,
                  commitment.id,
                  'commitment',
                )
              : null,
        ),
      ),
    ]);
    addGroup(
      MemoryGroup.rules,
      saved.rules
          .map(
            (rule) => RuleMemoryTile(
              rule: rule,
              onEdit: () => onEditRule(rule),
              onDeactivate: rule.active
                  ? () => onArchiveStructuredMemory(
                      MemoryLayer.rules,
                      rule.id,
                      'rule',
                    )
                  : null,
            ),
          )
          .toList(growable: false),
    );
    addGroup(
      MemoryGroup.recent,
      saved.recent.map(_memoryTile).toList(growable: false),
    );
    addGroup(
      MemoryGroup.other,
      saved.other.map(_memoryTile).toList(growable: false),
    );

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
  const _MemoryGroupHeader({required this.group});

  final MemoryGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        RexUiTokens.space24,
        RexUiTokens.space16,
        RexUiTokens.space8,
      ),
      child: Text(
        group.label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: RexUiTokens.text,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
