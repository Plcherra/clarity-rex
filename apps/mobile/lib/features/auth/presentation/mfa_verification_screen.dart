import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/clarity_gradients.dart';
import '../../../widgets/clarity_button.dart';
import '../../../widgets/clarity_card.dart';
import '../application/auth_controller.dart';

final class MfaVerificationScreen extends StatefulWidget {
  const MfaVerificationScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<MfaVerificationScreen> createState() => _MfaVerificationScreenState();
}

final class _MfaVerificationScreenState extends State<MfaVerificationScreen> {
  final _codeController = TextEditingController();
  String? _selectedFactorId;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadMfaFactors();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.replaceAll(RegExp(r'\D'), '');
    setState(() => _localError = null);
    if (code.length != 6) {
      setState(() => _localError = 'Enter the 6-digit code.');
      return;
    }
    await widget.controller.verifyMfaSignIn(
      code: code,
      factorId: _selectedFactorId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final factors = controller.mfaFactors;
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final error = _localError ?? controller.mfaErrorMessage;

        if (_selectedFactorId == null && factors.isNotEmpty) {
          _selectedFactorId = factors.first.id;
        }

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: ClarityGradients.appBackground,
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ClarityCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 48,
                            color: cs.primary,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Enter your MFA code',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Open your authenticator app and enter the current 6-digit code for Clarity.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (factors.length > 1) ...[
                            DropdownButtonFormField<String>(
                              initialValue: _selectedFactorId,
                              decoration: const InputDecoration(
                                labelText: 'Authenticator app',
                              ),
                              items: [
                                for (final factor in factors)
                                  DropdownMenuItem(
                                    value: factor.id,
                                    child: Text(factor.name),
                                  ),
                              ],
                              onChanged: controller.isMfaLoading
                                  ? null
                                  : (value) {
                                      setState(() => _selectedFactorId = value);
                                    },
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextField(
                            controller: _codeController,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: '6-digit code',
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
                          const SizedBox(height: 22),
                          ClarityButton.filled(
                            label: 'Verify and continue',
                            onPressed: _submit,
                            icon: const Icon(Icons.lock_open_rounded),
                            isLoading: controller.isMfaLoading,
                            expanded: true,
                          ),
                          const SizedBox(height: 12),
                          ClarityButton.text(
                            label: 'Sign out',
                            onPressed: controller.isMfaLoading
                                ? null
                                : controller.cancelMfaSignIn,
                            expanded: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
