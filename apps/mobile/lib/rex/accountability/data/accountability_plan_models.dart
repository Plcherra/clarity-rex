part of 'accountability_models.dart';

/// Goals and their steps: the records behind the Goals tab.

class PlanHierarchyItem {
  const PlanHierarchyItem({
    required this.plan,
    required this.openMilestones,
    required this.completedMilestones,
    required this.counts,
  });

  factory PlanHierarchyItem.fromJson(Map<String, dynamic> json) {
    return PlanHierarchyItem(
      plan: PlanRecord.fromJson(_map(json['plan'])),
      openMilestones: _list(json['open_milestones'], PlanMilestone.fromJson),
      completedMilestones: _list(
        json['completed_milestones'],
        PlanMilestone.fromJson,
      ),
      counts: _map(json['counts']),
    );
  }

  final PlanRecord plan;
  final List<PlanMilestone> openMilestones;
  final List<PlanMilestone> completedMilestones;
  final Map<String, dynamic> counts;
}

class PlanRecord {
  const PlanRecord({
    required this.id,
    required this.planType,
    required this.title,
    required this.description,
    required this.desiredOutcome,
    required this.priority,
    required this.status,
    required this.active,
    required this.startDate,
    required this.targetDate,
    required this.targetAmount,
    required this.completedAt,
    required this.lastReviewedAt,
    this.createdAt,
  });

  factory PlanRecord.fromJson(Map<String, dynamic> json) {
    return PlanRecord(
      id: _string(json['id']) ?? '',
      planType: _string(json['plan_type']) ?? 'other',
      title: _string(json['title']) ?? 'Plan',
      description: _string(json['description']),
      desiredOutcome: _string(json['desired_outcome']),
      priority: _int(json['priority']) ?? 3,
      status: _string(json['status']) ?? 'active',
      active: _bool(json['active']) ?? true,
      startDate: _dateTime(json['start_date']),
      targetDate: _dateTime(json['target_date']),
      targetAmount: _double(json['target_amount']) ?? 0,
      completedAt: _dateTime(json['completed_at']),
      lastReviewedAt: _dateTime(json['last_reviewed_at']),
      createdAt: _dateTime(json['created_at']),
    );
  }

  final String id;
  final String planType;
  final String title;
  final String? description;
  final String? desiredOutcome;
  final int priority;
  final String status;
  final bool active;
  final DateTime? startDate;
  final DateTime? targetDate;

  /// Dollars this goal needs. 0 means it is not a money goal.
  final double targetAmount;
  final DateTime? completedAt;
  final DateTime? lastReviewedAt;

  /// When the goal was set — the start of the run when no start date was given.
  final DateTime? createdAt;
}

class PlanMilestone {
  const PlanMilestone({
    required this.id,
    required this.planId,
    required this.title,
    required this.description,
    required this.milestoneType,
    required this.targetDate,
    required this.priority,
    required this.status,
    required this.active,
    required this.completedAt,
  });

  factory PlanMilestone.fromJson(Map<String, dynamic> json) {
    return PlanMilestone(
      id: _string(json['id']) ?? '',
      planId: _string(json['plan_id']) ?? '',
      title: _string(json['title']) ?? 'Milestone',
      description: _string(json['description']),
      milestoneType: _string(json['milestone_type']) ?? 'checkpoint',
      targetDate: _dateTime(json['target_date']),
      priority: _int(json['priority']) ?? 3,
      status: _string(json['status']) ?? 'open',
      active: _bool(json['active']) ?? true,
      completedAt: _dateTime(json['completed_at']),
    );
  }

  final String id;
  final String planId;
  final String title;
  final String? description;
  final String milestoneType;
  final DateTime? targetDate;
  final int priority;
  final String status;
  final bool active;
  final DateTime? completedAt;
}
