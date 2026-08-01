import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../../core/supabase/supabase_service.dart';
import '../domain/assistant_proposal_settings.dart';

final class ProfileService {
  ProfileService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  User get _currentUser {
    final user = _supabaseService.auth.currentUser;
    if (user == null) throw const SupabaseAuthRequiredException();
    return user;
  }

  Future<ProfileRecord?> fetchCurrentProfile() async {
    final user = _currentUser;
    try {
      final row = await _supabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return null;
      return ProfileRecord.fromJson(row);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'profiles',
        action: 'fetchCurrentProfile',
        message: 'Could not fetch the current profile.',
        cause: e,
      );
    }
  }

  Future<ProfileRecord> upsertCurrentProfile({
    String? email,
    String? fullName,
    String? avatarPath,
    String? preferredLocale,
  }) async {
    final user = _currentUser;
    try {
      final row = await _supabaseService.client
          .from('profiles')
          .upsert({
            'id': user.id,
            'email': email ?? user.email,
            'full_name': fullName,
            'avatar_path': avatarPath,
            'preferred_locale': ?preferredLocale,
          })
          .select()
          .single();
      return ProfileRecord.fromJson(row);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'profiles',
        action: 'upsertCurrentProfile',
        message: 'Could not upsert the current profile.',
        cause: e,
      );
    }
  }

  Future<ProfileRecord> updateCurrentProfile({
    String? email,
    String? fullName,
    String? preferredLocale,
    AssistantProposalSettings? assistantSettings,
  }) async {
    final user = _currentUser;
    final payload = <String, dynamic>{};
    if (email != null) payload['email'] = email;
    if (fullName != null) payload['full_name'] = fullName;
    if (preferredLocale != null) payload['preferred_locale'] = preferredLocale;
    if (assistantSettings != null) {
      payload['assistant_settings'] = assistantSettings.toJson();
    }
    if (payload.isEmpty) {
      throw const SupabaseDataException(
        table: 'profiles',
        action: 'updateCurrentProfile',
        message: 'At least one profile field is required.',
      );
    }

    try {
      final row = await _supabaseService.client
          .from('profiles')
          .update(payload)
          .eq('id', user.id)
          .select()
          .single();
      return ProfileRecord.fromJson(row);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'profiles',
        action: 'updateCurrentProfile',
        message: 'Could not update the current profile.',
        cause: e,
      );
    }
  }

  Future<ProfileRecord> updateAssistantProposalSettings(
    AssistantProposalSettings settings,
  ) async {
    return updateCurrentProfile(assistantSettings: settings);
  }

  /// Points the profile at a stored photo, or clears it when [path] is null.
  ///
  /// Separate from [updateCurrentProfile], where a null argument means "leave
  /// this field alone" — removing a photo has to be able to mean null.
  Future<ProfileRecord> setAvatarPath(String? path) async {
    final user = _currentUser;
    try {
      final row = await _supabaseService.client
          .from('profiles')
          .update({'avatar_path': path})
          .eq('id', user.id)
          .select()
          .single();
      return ProfileRecord.fromJson(row);
    } on SupabaseDataException {
      rethrow;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: 'profiles',
        action: 'setAvatarPath',
        message: 'Could not update the profile photo.',
        cause: e,
      );
    }
  }

  Stream<ProfileRecord?> watchCurrentProfile() {
    final user = _currentUser;
    return _supabaseService.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .map(
          (rows) => rows.isEmpty ? null : ProfileRecord.fromJson(rows.first),
        );
  }
}
