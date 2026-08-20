import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/features/finance/application/assistant_financial_context_service.dart';
import 'package:clarity/rex/presentation/assistant_chat_visible_provider.dart';

/// True when the financial read model already has at least one account.
///
/// Reloads when Chat becomes visible again so chips flip after a bank link
/// without a new API.
final hasLinkedAccountsProvider = FutureProvider<bool>((ref) async {
  ref.watch(assistantChatVisibleProvider);
  final service = ref.watch(assistantFinancialContextServiceProvider);
  if (service == null) {
    return false;
  }
  return service.hasLinkedAccounts();
});
