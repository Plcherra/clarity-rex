import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/mfa_verification_screen.dart';
import '../features/assistant/data/financial_context_service.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/shell/presentation/home_shell.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import 'ui_dependencies.dart';

final class ClarityApp extends StatelessWidget {
  const ClarityApp({
    super.key,
    required this.ui,
    required this.authController,
    required this.profileController,
  });

  final AppUiDependencies ui;
  final AuthController authController;
  final ProfileController profileController;

  static ThemeData buildTheme() {
    const seed = Color(0xFF1C1B19);
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFAFAF8),
    );
    const onPaper = Color(0xFFF7F5F2);
    const paper = Color(0xFFF8F7F4);
    const panel = Color(0xFFFFFEFC);
    final outlineSoft = base.outline.withValues(alpha: 0.35);

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: paper,
      textTheme: const TextTheme().apply(
        bodyColor: const Color(0xFF1C1B19),
        displayColor: const Color(0xFF1C1B19),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: base.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: base.onSurface,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFF4D4A43),
          minimumSize: const Size.square(44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: const Color(0xFF5B574E),
        textColor: const Color(0xFF1C1B19),
        subtitleTextStyle: TextStyle(
          color: base.onSurface.withValues(alpha: 0.56),
          fontSize: 14,
          height: 1.25,
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFF1C1B19),
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.22,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: const Color(0xFFEDE8DC),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF1C1B19)
                : base.onSurface.withValues(alpha: 0.62),
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          );
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: onPaper,
          backgroundColor: const Color(0xFF1C1B19),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1C1B19),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
            fontSize: 15,
          ),
          side: BorderSide(color: outlineSoft),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF1C1B19).withValues(alpha: 0.75),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outlineSoft,
        space: 1,
        thickness: 1,
      ),
    );
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
        listenable: authController,
        builder: (context, _) {
          return ListenableBuilder(
            listenable: profileController,
            builder: (context, _) {
              return MaterialApp(
                title: 'Clarity',
                debugShowCheckedModeBanner: false,
                theme: buildTheme(),
                home: _homeForCurrentState(),
              );
            },
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
    if (profileController.isLoading) {
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
      signOut: authController.signOut,
    );
  }
}

final class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
