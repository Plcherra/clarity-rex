class MemoryPagedResult<T> {
  const MemoryPagedResult({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  factory MemoryPagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) {
    final rawItems = json['items'];
    return MemoryPagedResult(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(fromJsonT)
                .toList(growable: false)
          : const [],
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] == true,
    );
  }

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}

class MemoryOverviewPages {
  const MemoryOverviewPages({
    this.memoriesCursor,
    this.memoriesHasMore = false,
    this.entitiesCursor,
    this.entitiesHasMore = false,
    this.rulesCursor,
    this.rulesHasMore = false,
    this.plansCursor,
    this.plansHasMore = false,
    this.commitmentsCursor,
    this.commitmentsHasMore = false,
  });

  final String? memoriesCursor;
  final bool memoriesHasMore;
  final String? entitiesCursor;
  final bool entitiesHasMore;
  final String? rulesCursor;
  final bool rulesHasMore;
  final String? plansCursor;
  final bool plansHasMore;
  final String? commitmentsCursor;
  final bool commitmentsHasMore;

  bool get hasMore =>
      memoriesHasMore ||
      entitiesHasMore ||
      rulesHasMore ||
      plansHasMore ||
      commitmentsHasMore;

  MemoryOverviewPages copyWith({
    String? memoriesCursor,
    bool? memoriesHasMore,
    String? entitiesCursor,
    bool? entitiesHasMore,
    String? rulesCursor,
    bool? rulesHasMore,
    String? plansCursor,
    bool? plansHasMore,
    String? commitmentsCursor,
    bool? commitmentsHasMore,
  }) {
    return MemoryOverviewPages(
      memoriesCursor: memoriesCursor ?? this.memoriesCursor,
      memoriesHasMore: memoriesHasMore ?? this.memoriesHasMore,
      entitiesCursor: entitiesCursor ?? this.entitiesCursor,
      entitiesHasMore: entitiesHasMore ?? this.entitiesHasMore,
      rulesCursor: rulesCursor ?? this.rulesCursor,
      rulesHasMore: rulesHasMore ?? this.rulesHasMore,
      plansCursor: plansCursor ?? this.plansCursor,
      plansHasMore: plansHasMore ?? this.plansHasMore,
      commitmentsCursor: commitmentsCursor ?? this.commitmentsCursor,
      commitmentsHasMore: commitmentsHasMore ?? this.commitmentsHasMore,
    );
  }
}

List<T> appendUniqueById<T>({
  required List<T> existing,
  required List<T> incoming,
  required String Function(T item) idFor,
}) {
  if (incoming.isEmpty) {
    return existing;
  }
  final seen = existing.map(idFor).toSet();
  final merged = [...existing];
  for (final item in incoming) {
    final id = idFor(item);
    if (seen.add(id)) {
      merged.add(item);
    }
  }
  return merged;
}
