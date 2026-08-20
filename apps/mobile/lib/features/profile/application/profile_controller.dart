import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_realtime_errors.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../auth/application/auth_service.dart';
import '../domain/assistant_proposal_settings.dart';
import 'avatar_storage_service.dart';
import 'locale_controller.dart';
import 'profile_service.dart';

const _onboardingNameCacheKey = 'profile_onboarding_completed_name';

final class ProfileController extends ChangeNotifier {
  ProfileController({
    required this.profileService,
    required this.authService,
    required this.syncAfterProfileChanged,
    required AvatarStorageService avatarStorage,
    LocaleController? localeController,
    SharedPreferencesAsync? preferences,
  }) : _avatarStorage = avatarStorage,
       _localeController = localeController,
       _preferences = preferences ?? SharedPreferencesAsync() {
    _authSubscription = authService.authStateChanges.listen((_) async {
      await hydrateProfileForCurrentUser();
    });
  }

  final ProfileService profileService;
  final AuthService authService;
  final Future<void> Function() syncAfterProfileChanged;
  final AvatarStorageService _avatarStorage;
  final LocaleController? _localeController;
  final SharedPreferencesAsync _preferences;
  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<ProfileRecord?>? _profileSubscription;
  var _profileRestartQueued = false;
  var _profileRestartAttempts = 0;

  ProfileRecord? profile;
  bool isLoading = false;

  /// True while companion Auto Suggestions mode/settings are persisting.
  bool isUpdatingAssistantSettings = false;

  /// True while a photo is uploading or being removed.
  bool isUpdatingAvatar = false;

  /// A temporary link to the stored photo, or null when there is none.
  ///
  /// Signed rather than stored, so it has to be fetched after the profile
  /// loads and refreshed whenever the photo changes.
  String? avatarSignedUrl;

  String? errorMessage;
  String? _cachedOnboardingName;
  String? _signedAvatarPath;

  bool get hasCompleteProfile {
    if (profile?.fullName?.trim().isNotEmpty ?? false) {
      return true;
    }
    return _cachedOnboardingName?.trim().isNotEmpty ?? false;
  }

  Future<void> hydrateProfileForCurrentUser() async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _profileRestartAttempts = 0;
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
      await _syncEmailFromIdentity();
      await _refreshAvatarUrl();
      await _localeController?.resolveAfterProfileHydrate(
        profilePreferredLocale: profile?.preferredLocale,
        seedProfileIfMissing:
            profile?.preferredLocale == null && authService.currentUser != null
            ? (localeTag) => updatePreferredLocale(localeTag)
            : null,
      );
      await _listenCurrentProfile();
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
    String? avatarPath,
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
        avatarPath: avatarPath,
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

  Future<void> updateAssistantProposalSettings(
    AssistantProposalSettings settings,
  ) async {
    if (profile?.assistantSettings == settings) {
      return;
    }
    isLoading = true;
    isUpdatingAssistantSettings = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await profileService.updateAssistantProposalSettings(settings);
      await syncAfterProfileChanged();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      isUpdatingAssistantSettings = false;
      notifyListeners();
    }
  }

  /// Stores a picked photo and points the profile at it.
  Future<void> setAvatarFromBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final previousPath = profile?.avatarPath;

    isUpdatingAvatar = true;
    errorMessage = null;
    notifyListeners();
    try {
      final path = await _avatarStorage.upload(
        bytes: bytes,
        fileName: fileName,
      );
      profile = await profileService.setAvatarPath(path);
      await _refreshAvatarUrl(force: true);
      // Only after the profile points at the new photo. Deleting first would
      // leave the profile aimed at nothing if the upload then failed.
      await _avatarStorage.remove(previousPath);
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isUpdatingAvatar = false;
      notifyListeners();
    }
  }

  Future<void> removeAvatar() async {
    final previousPath = profile?.avatarPath;
    if (previousPath == null || previousPath.isEmpty) return;

    isUpdatingAvatar = true;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await profileService.setAvatarPath(null);
      await _refreshAvatarUrl(force: true);
      await _avatarStorage.remove(previousPath);
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isUpdatingAvatar = false;
      notifyListeners();
    }
  }

  Future<void> _listenCurrentProfile() async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    if (authService.currentUser == null) return;
    await authService.refreshAuthSession();
    try {
      _profileSubscription = profileService.watchCurrentProfile().listen(
        (next) async {
          _profileRestartAttempts = 0;
          if (next != null) {
            profile = next;
            await _cacheOnboardingName(next.fullName);
          } else if (authService.currentUser == null) {
            profile = null;
            _cachedOnboardingName = null;
          }
          await _refreshAvatarUrl();
          await _localeController?.resolveAfterProfileHydrate(
            profilePreferredLocale: profile?.preferredLocale,
          );
          notifyListeners();
        },
        onError: (Object error, StackTrace stack) {
          _handleProfileStreamError(error);
        },
        cancelOnError: false,
      );
    } on SupabaseAuthRequiredException {
      rethrow;
    } on Object catch (error) {
      _handleProfileStreamError(error);
    }
  }

  void _handleProfileStreamError(Object error) {
    if (isRecoverableSupabaseRealtimeError(error)) {
      debugPrint('[Clarity][Realtime] profile: $error');
    }
    unawaited(_restartProfileWatch());
  }

  Future<void> _restartProfileWatch() async {
    if (_profileRestartQueued || _profileRestartAttempts >= 3) return;
    _profileRestartQueued = true;
    _profileRestartAttempts += 1;
    try {
      await authService.refreshAuthSession();
      await _listenCurrentProfile();
    } finally {
      _profileRestartQueued = false;
    }
  }

  /// Catches the profile row up to the email the account actually signs in
  /// with.
  ///
  /// An email change is confirmed by opening a link, which happens outside the
  /// app entirely — so the identity email can move without the app ever being
  /// told. The copy on the profile row exists for display and joins, and has
  /// to follow rather than be trusted.
  Future<void> _syncEmailFromIdentity() async {
    final current = profile;
    if (current == null) return;
    final identityEmail = authService.currentUser?.email?.trim();
    if (identityEmail == null || identityEmail.isEmpty) return;
    if (current.email?.trim() == identityEmail) return;
    try {
      profile = await profileService.updateCurrentProfile(email: identityEmail);
    } on Object {
      // Display already reads the identity email first, so a failed catch-up
      // shows nothing wrong and is retried on the next hydrate.
    }
  }

  /// Signs a fresh link when the stored photo has changed.
  ///
  /// The profile stream fires for every profile edit, and signing on each one
  /// would be a round trip to say the photo is still the photo.
  Future<void> _refreshAvatarUrl({bool force = false}) async {
    final path = profile?.avatarPath;
    if (!force && path == _signedAvatarPath) return;
    _signedAvatarPath = path;
    try {
      avatarSignedUrl = await _avatarStorage.signedUrl(path);
    } on Object {
      // A photo that will not load is not worth failing the screen over; the
      // header falls back to initials on its own. Forgetting the path is what
      // lets the next hydrate try again instead of treating one bad round trip
      // as the answer forever.
      avatarSignedUrl = null;
      _signedAvatarPath = null;
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
