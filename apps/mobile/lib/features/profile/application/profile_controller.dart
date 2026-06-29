import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../auth/application/auth_service.dart';
import 'locale_controller.dart';
import 'profile_service.dart';

final class ProfileController extends ChangeNotifier {
  ProfileController({
    required this.profileService,
    required this.authService,
    required this.syncAfterProfileChanged,
    LocaleController? localeController,
  }) : _localeController = localeController {
    _authSubscription = authService.authStateChanges.listen((_) async {
      await hydrateProfileForCurrentUser();
    });
  }

  final ProfileService profileService;
  final AuthService authService;
  final Future<void> Function() syncAfterProfileChanged;
  final LocaleController? _localeController;
  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<ProfileRecord?>? _profileSubscription;

  ProfileRecord? profile;
  bool isLoading = false;
  String? errorMessage;

  bool get hasCompleteProfile {
    return profile?.fullName?.trim().isNotEmpty ?? false;
  }

  Future<void> hydrateProfileForCurrentUser() async {
    final shouldBlockUi = profile == null;
    isLoading = shouldBlockUi;
    errorMessage = null;
    notifyListeners();

    await _profileSubscription?.cancel();
    _profileSubscription = null;

    try {
      if (authService.currentUser == null) {
        profile = null;
        return;
      }

      profile = await profileService.fetchCurrentProfile();
      await _localeController?.resolveAfterProfileHydrate(
        profilePreferredLocale: profile?.preferredLocale,
        seedProfileIfMissing:
            profile?.preferredLocale == null &&
                authService.currentUser != null
            ? (localeTag) => updatePreferredLocale(localeTag)
            : null,
      );
      _profileSubscription = profileService.watchCurrentProfile().listen((
        next,
      ) async {
        profile = next;
        await _localeController?.resolveAfterProfileHydrate(
          profilePreferredLocale: next?.preferredLocale,
        );
        notifyListeners();
      });
    } on SupabaseAuthRequiredException {
      profile = null;
    } catch (e) {
      errorMessage = e.toString();
      if (shouldBlockUi) {
        profile = null;
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> upsertCurrentProfile({
    String? email,
    String? fullName,
    String? avatarUrl,
    String? preferredLocale,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await profileService.upsertCurrentProfile(
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
        preferredLocale: preferredLocale,
      );
      await syncAfterProfileChanged();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCurrentProfile({
    String? email,
    String? fullName,
    String? avatarUrl,
    String? preferredLocale,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await profileService.updateCurrentProfile(
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
        preferredLocale: preferredLocale,
      );
      await syncAfterProfileChanged();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferredLocale(String localeTag) async {
    if (profile?.preferredLocale?.trim() == localeTag.trim()) {
      return;
    }
    await updateCurrentProfile(preferredLocale: localeTag);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
