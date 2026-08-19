import 'package:flutter/material.dart';

import 'package:clarity/features/owner_debug/presentation/owner_debug_panel.dart';

/// Hidden owner-only voice/build diagnostics. Not shown on Usage administration.
class OwnerDebugScreen extends StatelessWidget {
  const OwnerDebugScreen({super.key});

  static const title = 'Voice debug';

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const OwnerDebugScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('owner_debug_screen'),
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(title),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: const [OwnerDebugPanel()],
      ),
    );
  }
}
