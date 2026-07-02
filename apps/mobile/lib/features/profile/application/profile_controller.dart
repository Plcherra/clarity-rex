import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../auth/application/auth_service.dart';
import 'locale_controller.dart';
import 'profile_service.dart';

const _onboardingNameCacheKey = 'profile_onboarding_completed_name';

final class ProfileController extends ChangeNotifier {
  ProfileController({
    required this.profileService,
    required this.authService,
    required this.syncAfterProfileChanged,
    LocaleController? localeController,
    SharedPreferencesAsync? preferences,
  }) : _localeController = localeController,
       _preferences = preferences ?? SharedPreferencesAsync() {
    _authSubscription = authService.authStateChanges.listen((_) async {
      await hydrateProfileForCurrentUser();
    });
  }

  final ProfileService profileService;
  final AuthService authService;
  final Future<void> Function() syncAfterProfileChanged;
  final LocaleController? _localeController;
  final SharedPreferencesAsync _preferences;
  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<ProfileRecord?>? _profileSubscription;

  ProfileRecord? profile;
  bool isLoading = false;
  String? errorMessage;
  String? _cachedOnboardingName;

  bool get hasCompleteProfile {
    if (profile?.fullName?.trim().isNotEmpty ?? false) {
      return true;
    }
    return _cachedOnboardingName?.trim().isNotEmpty ?? false;
  }

  Future<void> hydrateProfileForCurrentUser() async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    var shouldBlockUi = profile == null && _cachedOnboardingName == null;

    try {
      if (authService.currentUser == null) {
        profile = null;
        _cachedOnboardingName = null;
        await _preferences.remove(_onboardingNameCacheKey);
        isLoading = false;
        notifyListeners();
        return;
      }

      _cachedOnboardingName = await _preferences.getString(
        _onboardingNameCacheKey,
      );
      shouldBlockUi = profile == null && _cachedOnboardingName == null;
      isLoading = shouldBlockUi;
      errorMessage = null;
      notifyListeners();

      profile = await profileService.fetchCurrentProfile();
      await _cacheOnboardingName(profile?.fullName);
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
        if (next != null) {
          profile = next;
          await _cacheOnboardingName(next.fullName);
        } else if (authService.currentUser == null) {
          profile = null;
          _cachedOnboardingName = null;
        }
        await _localeController?.resolveAfterProfileHydrate(
          profilePreferredLocale: profile?.preferredLocale,
        );
        notifyListeners();
      });
    } on SupabaseAuthRequiredException {
      profile = null;
    } catch (e) {
      errorMessage = e.toString();
      if (shouldBlockUi && _cachedOnboardingName == null) {
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
      await _cacheOnboardingName(fullName);
      profile = await profileService.upsertCurrentProfile(
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
        preferredLocale: preferredLocale,
      );
      await _cacheOnboardingName(profile?.fullName);
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
      await _cacheOnboardingName(fullName);
      profile = await profileService.updateCurrentProfile(
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
        preferredLocale: preferredLocale,
      );
      await _cacheOnboardingName(profile?.fullName);
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

  Future<void> updateProactiveInsightsEnabled(bool enabled) async {
    if (profile?.proactiveInsightsEnabled == enabled) {
      return;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await profileService.updateProactiveInsightsEnabled(enabled);
      await syncAfterProfileChanged();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _cacheOnboardingName(String? fullName) async {
    final normalized = fullName?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    _cachedOnboardingName = normalized;
    await _preferences.setString(_onboardingNameCacheKey, normalized);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
