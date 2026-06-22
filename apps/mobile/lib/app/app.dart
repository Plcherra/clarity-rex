import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/mfa_verification_screen.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/shell/presentation/home_shell.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../rex/data/financial_context_service.dart';
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
    const background = Color(0xFF080908);
    const surface = Color(0xFF111311);
    const surfaceSoft = Color(0xFF171A18);
    const surfaceRaised = Color(0xFF20231F);
    const border = Color(0xFF30352F);
    const text = Color(0xFFF2F1EA);
    const textMuted = Color(0xFFB7B3A7);
    const accent = Color(0xFFD7BF57);
    const accentStrong = Color(0xFFEBD56F);
    const danger = Color(0xFFFF706A);
    final base =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: accent,
          onPrimary: background,
          secondary: accentStrong,
          surface: background,
          onSurface: text,
          surfaceContainerLowest: background,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: surfaceSoft,
          surfaceContainerHighest: surfaceRaised,
          onSurfaceVariant: textMuted,
          outline: border,
          outlineVariant: border,
          error: danger,
          shadow: Colors.black,
        );
    final outlineSoft = border.withValues(alpha: 0.72);

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: const TextTheme().apply(bodyColor: text, displayColor: text),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        backgroundColor: surfaceRaised,
        contentTextStyle: const TextStyle(color: text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: background,
        foregroundColor: text,
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
          foregroundColor: textMuted,
          minimumSize: const Size.square(44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textMuted,
        textColor: text,
        subtitleTextStyle: const TextStyle(
          color: textMuted,
          fontSize: 14,
          height: 1.25,
        ),
        titleTextStyle: const TextStyle(
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.22,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : textMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected) ? text : textMuted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          );
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: background,
          backgroundColor: accent,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
            fontSize: 15,
          ),
          side: BorderSide(color: outlineSoft),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent),
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
                darkTheme: buildTheme(),
                themeMode: ThemeMode.dark,
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
