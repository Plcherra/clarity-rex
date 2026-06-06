import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/features/assistant/assistant_providers.dart';
import 'package:clarity/features/assistant/chat/data/chat_models.dart';
import 'package:clarity/features/assistant/chat/presentation/widgets/conversation_history_widgets.dart';
import 'package:clarity/features/assistant/presentation/rex_surfaces.dart';
import 'package:clarity/features/assistant/presentation/rex_ui_tokens.dart';

class ConversationListPage extends ConsumerStatefulWidget {
  const ConversationListPage({
    super.key,
    this.showAppBar = true,
    this.onConversationSelected,
  });

  final bool showAppBar;
  final VoidCallback? onConversationSelected;

  @override
  ConsumerState<ConversationListPage> createState() =>
      _ConversationListPageState();
}

class _ConversationListPageState extends ConsumerState<ConversationListPage>
    with AutomaticKeepAliveClientMixin<ConversationListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(conversationListProvider.notifier).loadConversations(),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _openConversation(Conversation conversation) async {
    await ref.read(chatProvider.notifier).loadConversation(conversation.id);
    if (!mounted) {
      return;
    }

    if (widget.onConversationSelected != null) {
      widget.onConversationSelected!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _newConversation() async {
    final conversation = await ref
        .read(conversationListProvider.notifier)
        .createConversation();
    if (conversation == null) {
      return;
    }

    ref.read(chatProvider.notifier).startConversation(conversation.id);
    if (!mounted) {
      return;
    }

    if (widget.onConversationSelected != null) {
      widget.onConversationSelected!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RexUiTokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Delete conversation?',
          style: TextStyle(color: RexUiTokens.text),
        ),
        content: const Text(
          'This removes the conversation and its messages from Clarity.',
          style: TextStyle(color: RexUiTokens.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: RexUiTokens.textMuted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: RexUiTokens.danger,
              foregroundColor: RexUiTokens.background,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final wasCurrent = ref.read(chatProvider).conversationId == conversation.id;
    final deleted = await ref
        .read(conversationListProvider.notifier)
        .deleteConversation(conversation.id);

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (!deleted) {
      final errorMessage =
          ref.read(conversationListProvider).errorMessage ??
          'Could not delete conversation.';
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Conversation deleted')),
    );

    if (wasCurrent) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(conversationListProvider);
    final currentConversation = ref.watch(currentConversationProvider);

    final body = RefreshIndicator(
      color: RexUiTokens.accent,
      backgroundColor: RexUiTokens.surfaceRaised,
      onRefresh: () =>
          ref.read(conversationListProvider.notifier).loadConversations(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (!widget.showAppBar)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chats',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: RexUiTokens.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: state.isLoading ? null : _newConversation,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'New conversation',
                      color: RexUiTokens.accent,
                    ),
                  ],
                ),
              ),
            ),
          if (state.errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _HistoryErrorBanner(message: state.errorMessage!),
              ),
            ),
          if (state.isLoading && state.conversations.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: RexUiTokens.accent),
              ),
            )
          else if (state.conversations.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _EmptyConversationState(
                    isLoading: state.isLoading,
                    onNewConversation: _newConversation,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate(
                conversationGroups(state.conversations)
                    .expand<Widget>(
                      (group) => [
                        ConversationDateHeader(label: group.label),
                        for (final conversation in group.conversations)
                          ConversationHistoryTile(
                            conversation: conversation,
                            isSelected:
                                conversation.id == currentConversation?.id,
                            onTap: () => _openConversation(conversation),
                            onDelete: () => _deleteConversation(conversation),
                          ),
                      ],
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );

    return RexScaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Chats'),
              actions: [
                IconButton(
                  onPressed: state.isLoading ? null : _newConversation,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'New conversation',
                  color: RexUiTokens.accent,
                ),
              ],
            )
          : null,
      body: body,
    );
  }
}

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState({
    required this.isLoading,
    required this.onNewConversation,
  });

  final bool isLoading;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RexSurface(
      padding: const EdgeInsets.all(RexUiTokens.space24),
      color: RexUiTokens.surface,
      radius: RexUiTokens.radiusLarge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, color: RexUiTokens.accent, size: 34),
          const SizedBox(height: RexUiTokens.space16),
          Text(
            'No chats yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: RexUiTokens.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: RexUiTokens.space8),
          Text(
            'Start a fresh conversation when you are ready.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: RexUiTokens.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: RexUiTokens.space20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: RexUiTokens.accent,
              foregroundColor: RexUiTokens.background,
            ),
            onPressed: isLoading ? null : onNewConversation,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New chat'),
          ),
        ],
      ),
    );
  }
}

class _HistoryErrorBanner extends StatelessWidget {
  const _HistoryErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return RexSurface(
      padding: const EdgeInsets.all(RexUiTokens.space16),
      color: RexUiTokens.danger.withValues(alpha: 0.12),
      borderColor: RexUiTokens.danger.withValues(alpha: 0.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: RexUiTokens.danger,
            size: 20,
          ),
          const SizedBox(width: RexUiTokens.space12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RexUiTokens.text,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
