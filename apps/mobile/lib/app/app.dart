import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/mfa_verification_screen.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/profile/application/theme_mode_controller.dart';
import '../features/shell/presentation/home_shell.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../rex/data/financial_context_service.dart';
import '../theme/clarity_theme.dart';
import '../widgets/clarity_diamond_loader.dart';
import 'ui_dependencies.dart';

final class ClarityApp extends StatelessWidget {
  const ClarityApp({
    super.key,
    required this.ui,
    required this.authController,
    required this.profileController,
    required this.themeModeController,
  });

  final AppUiDependencies ui;
  final AuthController authController;
  final ProfileController profileController;
  final ThemeModeController themeModeController;

  static ThemeData buildTheme() {
    return ClarityTheme.dark();
  }

  static ThemeData buildLightTheme() {
    return ClarityTheme.light();
  }

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
      ],
      child: ListenableBuilder(
        listenable: Listenable.merge([
          authController,
          profileController,
          themeModeController,
        ]),
        builder: (context, _) {
          return MaterialApp(
            title: 'Clarity',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildTheme(),
            themeMode: themeModeController.themeMode,
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
      signOut: authController.signOut,
    );
  }
}

final class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: ClarityDiamondLoader(size: 64, label: 'Loading Clarity'),
      ),
    );
  }
}
