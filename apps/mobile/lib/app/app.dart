import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_l10n.dart';
import '../core/l10n/clarity_material_app.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/mfa_verification_screen.dart';
import '../features/profile/application/locale_controller.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/profile/application/theme_mode_controller.dart';
import '../features/shell/presentation/home_shell.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../l10n/app_localizations.dart';
import '../rex/chat/application/chat_action_result_formatter.dart';
import '../rex/chat/application/chat_controller.dart';
import '../rex/chat/data/chat_api.dart';
import '../rex/data/financial_context_service.dart';
import '../rex/voice/application/voice_call_controller_providers.dart';
import '../rex/voice/data/streaming_voice_api.dart';
import '../widgets/clarity_diamond_loader.dart';
import 'ui_dependencies.dart';

export 'package:clarity/features/profile/application/locale_controller.dart'
    show localeControllerProvider;

final class ClarityApp extends StatelessWidget {
  const ClarityApp({
    super.key,
    required this.ui,
    required this.authController,
    required this.profileController,
    required this.themeModeController,
    required this.localeController,
  });

  final AppUiDependencies ui;
  final AuthController authController;
  final ProfileController profileController;
  final ThemeModeController themeModeController;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        assistantFinancialContextServiceProvider.overrideWithValue(
          AssistantFinancialContextService(
            loadFinancialReadModel: ui.dashboard.loadFinancialReadModel,
            spendReference: () => ui.budgets.spendReference,
            notifyDataChanged: ui.notifyDataChanged,
          ),
        ),
        localeControllerProvider.overrideWithValue(localeController),
        chatApiProvider.overrideWith(
          (ref) => ChatApi(
            resolveLocale: () => ref.read(localeControllerProvider).languageCode,
          ),
        ),
        streamingVoiceApiProvider.overrideWith(
          (ref) => StreamingVoiceApi(
            resolveLocale: () => ref.read(localeControllerProvider).languageCode,
          ),
        ),
        actionResultMessageFormatterProvider.overrideWith(
          (ref) {
            final languageCode = ref.watch(localeControllerProvider).languageCode;
            final l10n = lookupAppLocalizations(Locale(languageCode));
            return (action, result) =>
                actionResultMessage(l10n, action, result);
          },
        ),
      ],
      child: ListenableBuilder(
        listenable: Listenable.merge([
          authController,
          profileController,
          themeModeController,
          localeController,
        ]),
        builder: (context, _) {
          return ClarityMaterialApp(
            themeModeController: themeModeController,
            localeController: localeController,
            home: _homeForCurrentState(),
          );
        },
      ),
    );
  }

  Widget _homeForCurrentState() {
    if (authController.isLoading) {
      return const _AppLoadingScreen();
    }
    if (!authController.isAuthenticated) {
      return AuthScreen(controller: authController);
    }
    if (authController.isMfaRequired) {
      return MfaVerificationScreen(controller: authController);
    }
    if (profileController.isLoading && profileController.profile == null) {
      return const _AppLoadingScreen();
    }
    if (!profileController.hasCompleteProfile) {
      return OnboardingScreen(
        saveProfileName: (fullName) {
          return profileController.upsertCurrentProfile(fullName: fullName);
        },
        ui: ui,
      );
    }
    return HomeShell(
      ui: ui,
      authController: authController,
      profileController: profileController,
      themeModeController: themeModeController,
      localeController: localeController,
      signOut: authController.signOut,
    );
  }
}

final class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ClarityDiamondLoader(
          size: 64,
          label: context.l10n.loadingClarity,
        ),
      ),
    );
  }
}
