import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../theme/clarity_colors.dart';
import '../../../widgets/clarity_button.dart';
import '../../../widgets/clarity_card.dart';
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.bindLocalizations(context.l10n);
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

  Future<void> _toggleMfa(bool enabled) async {
    if (enabled) {
      await _startEnrollment();
      return;
    }

    final l10n = context.l10n;
    final factorCount = widget.controller.mfaFactors.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mfaEnrollmentTurnOffTitle),
        content: Text(
          factorCount <= 1
              ? l10n.mfaEnrollmentTurnOffBodySingle
              : l10n.mfaEnrollmentTurnOffBodyMultiple(factorCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.mfaEnrollmentTurnOff),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.disableMfa();
    }
  }

  Future<void> _verifyEnrollment() async {
    final code = _codeController.text.replaceAll(RegExp(r'\D'), '');
    setState(() => _localError = null);
    if (code.length != 6) {
      setState(() => _localError = context.l10n.mfaEnterSixDigitCode);
      return;
    }
    await widget.controller.verifyMfaEnrollment(code: code);
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.commonCopiedLabel(label))),
    );
  }

  Future<void> _confirmUnenroll(MfaFactorSummary factor) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mfaEnrollmentRemoveTitle),
        content: Text(l10n.mfaEnrollmentRemoveBody(factor.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonRemove),
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
        final l10n = context.l10n;
        final error = _localError ?? controller.mfaErrorMessage;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.mfaEnrollmentAppBarTitle)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _SecurityStatusCard(
                enabled: controller.hasVerifiedTotpFactor,
                isLoading: controller.isMfaLoading,
                onChanged: _toggleMfa,
                onEnroll: _startEnrollment,
              ),
              const SizedBox(height: 14),
              if (controller.mfaFactors.isNotEmpty) ...[
                Text(
                  l10n.mfaEnrollmentAuthenticatorApps,
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
                  onCopySecret: () => _copy(
                    enrollment.secret,
                    l10n.mfaEnrollmentManualSetupKeyCopyLabel,
                  ),
                  onCopyUri: () => _copy(
                    enrollment.uri,
                    l10n.mfaEnrollmentAuthenticatorUriCopyLabel,
                  ),
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
    required this.onChanged,
    required this.onEnroll,
  });

  final bool enabled;
  final bool isLoading;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    return ClarityCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: isLoading ? null : onChanged,
            secondary: Icon(
              enabled ? Icons.verified_user_rounded : Icons.security_rounded,
              color: enabled ? ClarityColors.financePositive : cs.primary,
            ),
            title: Text(
              enabled ? l10n.mfaEnrollmentMfaOn : l10n.mfaEnrollmentMfaOff,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            enabled
                ? l10n.mfaEnrollmentMfaOnDescription
                : l10n.mfaEnrollmentMfaOffDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (enabled)
            ClarityButton.outlined(
              label: l10n.mfaEnrollmentAddAnotherApp,
              onPressed: isLoading ? null : onEnroll,
              icon: const Icon(Icons.add_moderator_outlined),
            )
          else
            ClarityButton.filled(
              label: l10n.mfaEnrollmentTurnOnMfa,
              onPressed: isLoading ? null : () => onChanged(true),
              icon: const Icon(Icons.add_moderator_outlined),
            ),
        ],
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
    final l10n = context.l10n;
    return ClarityCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.mfaEnrollmentSetupTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.mfaEnrollmentSetupInstructions,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.78),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: enrollment.uri,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: cs.surfaceContainerHighest,
                  eyeStyle: QrEyeStyle(color: cs.onSurface),
                  dataModuleStyle: QrDataModuleStyle(color: cs.onSurface),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SecretRow(secret: enrollment.secret, onCopy: onCopySecret),
          TextButton.icon(
            onPressed: onCopyUri,
            icon: const Icon(Icons.copy_rounded),
            label: Text(l10n.mfaEnrollmentCopyAuthenticatorUri),
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
            decoration: InputDecoration(labelText: l10n.mfaEnrollmentCodeLabel),
          ),
          const SizedBox(height: 14),
          ClarityButton.filled(
            label: l10n.mfaEnrollmentEnableMfa,
            onPressed: isLoading ? null : onVerify,
            icon: const Icon(Icons.verified_rounded),
            isLoading: isLoading,
            expanded: true,
          ),
        ],
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
    final l10n = context.l10n;
    return ClarityCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      borderColor: cs.outline.withValues(alpha: 0.24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.mfaEnrollmentManualSetupKey,
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
            tooltip: l10n.mfaEnrollmentCopyManualSetupKeyTooltip,
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
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
    final l10n = context.l10n;
    return ClarityCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.phonelink_lock_rounded),
        title: Text(factor.name),
        subtitle: Text(l10n.commonAddedDate(_shortDate(factor.createdAt))),
        trailing: IconButton(
          tooltip: l10n.mfaEnrollmentRemoveAuthenticatorTooltip,
          onPressed: isBusy ? null : onRemove,
          icon: const Icon(Icons.delete_outline_rounded),
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
    return ClarityCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      borderColor: cs.outline.withValues(alpha: 0.24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.mfaEnrollmentRecoveryNotice,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}
