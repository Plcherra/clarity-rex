import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_exceptions.dart';
import '../../../core/supabase/supabase_service.dart';

/// Thrown when a picked file is not an image the bucket accepts.
///
/// Caught before the upload so the user is told what is wrong, rather than
/// being handed whatever storage says about a rejected mime type.
final class UnsupportedAvatarFormatException implements Exception {
  const UnsupportedAvatarFormatException(this.fileName);

  final String fileName;

  @override
  String toString() => 'Unsupported avatar format: $fileName';
}

/// Profile photos in the private `avatars` bucket.
///
/// A stored path is `<user id>/<epoch ms>.<ext>`. The folder is the only thing
/// the storage policies check, so it has to be the user's id and nothing else.
/// The changing filename is deliberate: replacing a photo under a fixed name
/// would keep serving the old one out of the image cache.
final class AvatarStorageService {
  AvatarStorageService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  static const String bucket = 'avatars';

  /// Matches the bucket's `allowed_mime_types`.
  static const Set<String> allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Long enough to outlast a session with the app left open, short enough
  /// that a link which escaped is dead before it is any use.
  static const Duration signedUrlLifetime = Duration(hours: 6);

  User get _currentUser {
    final user = _supabaseService.auth.currentUser;
    if (user == null) throw const SupabaseAuthRequiredException();
    return user;
  }

  /// Stores [bytes] and returns the path to save on the profile.
  Future<String> upload({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = _currentUser;
    final mimeType = lookupMimeType(fileName, headerBytes: _header(bytes));
    if (mimeType == null || !allowedMimeTypes.contains(mimeType)) {
      throw UnsupportedAvatarFormatException(fileName);
    }

    final path =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}'
        '.${_extensionFor(mimeType)}';
    try {
      await _supabaseService.client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType),
          );
      return path;
    } on Object catch (e) {
      throw SupabaseDataException(
        table: bucket,
        action: 'uploadAvatar',
        message: 'Could not upload the profile photo.',
        cause: e,
      );
    }
  }

  /// A temporary link the app can render, or null when there is no photo.
  Future<String?> signedUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await _supabaseService.client.storage
          .from(bucket)
          .createSignedUrl(path, signedUrlLifetime.inSeconds);
    } on Object catch (e) {
      throw SupabaseDataException(
        table: bucket,
        action: 'signAvatarUrl',
        message: 'Could not load the profile photo.',
        cause: e,
      );
    }
  }

  /// Deletes a stored photo. Failures are swallowed on purpose: this runs
  /// after the profile already points somewhere else, and an orphaned object
  /// the user cannot see is not worth an error they cannot act on.
  Future<void> remove(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await _supabaseService.client.storage.from(bucket).remove([path]);
    } on Object {
      return;
    }
  }

  /// The sniffer only needs the first bytes, and a photo can be megabytes.
  static Uint8List _header(Uint8List bytes) {
    final end = bytes.length < defaultMagicNumbersMaxLength
        ? bytes.length
        : defaultMagicNumbersMaxLength;
    return Uint8List.sublistView(bytes, 0, end);
  }

  static String _extensionFor(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }
}
