import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../application/auth_controller.dart';
import '../application/auth_service.dart';

final class MfaEnrollmentScreen extends StatefulWidget {
  const MfaEnrollmentScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<MfaEnrollmentScreen> createState() => _MfaEnrollmentScreenState();
}

final class _MfaEnrollmentScreenState extends State<MfaEnrollmentScreen> {
  final _codeController = TextEditingController();
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.refreshMfaFactors();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    _codeController.clear();
    setState(() => _localError = null);
    await widget.controller.beginMfaEnrollment();
  }

  Future<void> _verifyEnrollment() async {
    final code = _codeController.text.replaceAll(RegExp(r'\D'), '');
    setState(() => _localError = null);
    if (code.length != 6) {
      setState(() => _localError = 'Enter the 6-digit code.');
      return;
    }
    await widget.controller.verifyMfaEnrollment(code: code);
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  Future<void> _confirmUnenroll(MfaFactorSummary factor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove MFA?'),
        content: Text(
          'Remove ${factor.name}? You can enroll another authenticator app later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.unenrollMfaFactor(factor.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final enrollment = controller.pendingMfaEnrollment;
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final error = _localError ?? controller.mfaErrorMessage;

        return Scaffold(
          appBar: AppBar(title: const Text('Multi-factor authentication')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _SecurityStatusCard(
                enabled: controller.hasVerifiedTotpFactor,
                isLoading: controller.isMfaLoading,
                onEnroll: _startEnrollment,
              ),
              const SizedBox(height: 14),
              if (controller.mfaFactors.isNotEmpty) ...[
                Text(
                  'Authenticator apps',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final factor in controller.mfaFactors) ...[
                  _FactorTile(
                    factor: factor,
                    isBusy: controller.isMfaLoading,
                    onRemove: () => _confirmUnenroll(factor),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 14),
              ],
              if (enrollment != null)
                _EnrollmentCard(
                  enrollment: enrollment,
                  codeController: _codeController,
                  isLoading: controller.isMfaLoading,
                  onVerify: _verifyEnrollment,
                  onCopySecret: () =>
                      _copy(enrollment.secret, 'Manual setup key'),
                  onCopyUri: () => _copy(enrollment.uri, 'Authenticator URI'),
                ),
              if (error != null && error.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  error,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (controller.mfaInfoMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  controller.mfaInfoMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const _RecoveryNotice(),
            ],
          ),
        );
      },
    );
  }
}

final class _SecurityStatusCard extends StatelessWidget {
  const _SecurityStatusCard({
    required this.enabled,
    required this.isLoading,
    required this.onEnroll,
  });

  final bool enabled;
  final bool isLoading;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  enabled
                      ? Icons.verified_user_rounded
                      : Icons.security_rounded,
                  color: enabled ? const Color(0xFF1B7A4C) : cs.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    enabled ? 'MFA is enabled' : 'MFA is optional',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              enabled
                  ? 'Your account requires an authenticator code after password sign-in.'
                  : 'Add an authenticator app to protect your financial workspace.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: isLoading ? null : onEnroll,
              icon: const Icon(Icons.add_moderator_outlined),
              label: Text(enabled ? 'Add another app' : 'Enroll in MFA'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({
    required this.enrollment,
    required this.codeController,
    required this.isLoading,
    required this.onVerify,
    required this.onCopySecret,
    required this.onCopyUri,
  });

  final MfaEnrollment enrollment;
  final TextEditingController codeController;
  final bool isLoading;
  final VoidCallback onVerify;
  final VoidCallback onCopySecret;
  final VoidCallback onCopyUri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set up authenticator app',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan this QR code in 1Password, Google Authenticator, Authy, or another TOTP app.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE9E3D8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: enrollment.uri,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SecretRow(secret: enrollment.secret, onCopy: onCopySecret),
            TextButton.icon(
              onPressed: onCopyUri,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy authenticator URI'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onSubmitted: (_) => onVerify(),
              decoration: const InputDecoration(
                labelText: '6-digit code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: isLoading ? null : onVerify,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_rounded),
              label: const Text('Enable MFA'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SecretRow extends StatelessWidget {
  const _SecretRow({required this.secret, required this.onCopy});

  final String secret;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual setup key',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    secret,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy manual setup key',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

final class _FactorTile extends StatelessWidget {
  const _FactorTile({
    required this.factor,
    required this.isBusy,
    required this.onRemove,
  });

  final MfaFactorSummary factor;
  final bool isBusy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        leading: const Icon(Icons.phonelink_lock_rounded),
        title: Text(factor.name),
        subtitle: Text('Added ${_shortDate(factor.createdAt)}'),
        trailing: IconButton(
          tooltip: 'Remove authenticator app',
          onPressed: isBusy ? null : onRemove,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.24)),
        ),
        titleTextStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

final class _RecoveryNotice extends StatelessWidget {
  const _RecoveryNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Supabase Auth does not provide recovery codes for TOTP. Add a second authenticator app as a backup before removing your only factor.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}
