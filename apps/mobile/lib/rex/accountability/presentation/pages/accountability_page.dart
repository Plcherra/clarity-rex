import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/rex/assistant_providers.dart';
import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

part 'accountability_page_sections.dart';
part 'accountability_page_shared.dart';
part 'accountability_page_tiles.dart';

class AccountabilityPage extends ConsumerStatefulWidget {
  const AccountabilityPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<AccountabilityPage> createState() => _AccountabilityPageState();
}

class _AccountabilityPageState extends ConsumerState<AccountabilityPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(accountabilityProvider.notifier).loadOverview(),
    );
  }

  Future<void> _refresh() {
    return ref.read(accountabilityProvider.notifier).loadOverview();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountabilityProvider);
    final overview = state.overview;

    return RexScaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Goals'),
              actions: [
                IconButton(
                  onPressed: state.isLoading ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh goals',
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        color: RexUiTokens.accent,
        backgroundColor: RexUiTokens.surfaceRaised,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                RexUiTokens.space16,
                RexUiTokens.space8,
                RexUiTokens.space16,
                RexUiTokens.space24,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (state.errorMessage != null)
                    _ErrorBanner(message: state.errorMessage!),
                  if (state.isLoading && overview == null)
                    const _InitialLoading()
                  else if (overview == null || overview.isEmpty)
                    const _EmptyAccountabilityState()
                  else ...[
                    _OverviewSummary(overview: overview),
                    const SizedBox(height: 20),
                    _SignalSection(signals: overview.signals),
                    const SizedBox(height: 20),
                    _RuleSection(rules: overview.activeRules),
                    const SizedBox(height: 20),
                    _CommitmentSection(
                      commitments: overview.openCommitments
                          .where(
                            (commitment) =>
                                commitment.planId == null &&
                                commitment.milestoneId == null,
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 20),
                    _PlanSection(
                      planHierarchy: overview.planHierarchy,
                      plans: overview.activePlans,
                      milestones: overview.openMilestones,
                      completedMilestones: overview.completedMilestones,
                    ),
                    if (overview.duplicateWarnings.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _DuplicateWarningSection(
                        warnings: overview.duplicateWarnings,
                      ),
                    ],
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
