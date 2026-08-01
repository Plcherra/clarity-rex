import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/layout/clarity_adaptive_overlay.dart';
import '../../../core/platform/app_capabilities.dart';
import '../../../theme/clarity_colors.dart';
import '../application/avatar_storage_service.dart';
import '../application/profile_controller.dart';

/// Matches the bucket's `file_size_limit`, so an oversized photo is refused
/// here with something readable instead of by storage with something not.
const int _maxAvatarBytes = 2 * 1024 * 1024;

/// Long edge the photo is reduced to before upload.
///
/// A profile photo is never shown larger than a thumbnail, so anything past
/// this is bytes the user waits on and pays for and never sees.
const double _maxAvatarEdge = 720;

enum _PhotoAction { camera, library, remove }

/// Picks a new profile photo, or removes the current one.
Future<void> showProfilePhotoActions(
  BuildContext context, {
  required ProfileController controller,
}) async {
  final hasPhoto = (controller.profile?.avatarPath ?? '').isNotEmpty;
  final action = await showClarityAdaptiveOverlay<_PhotoAction>(
    context: context,
    backgroundColor: context.clarityColors.surfaceElevated,
    dialogMaxWidth: 420,
    dialogMaxHeight: 320,
    builder: (_) => _PhotoActionSheet(hasPhoto: hasPhoto),
  );
  if (action == null || !context.mounted) return;

  if (action == _PhotoAction.remove) {
    await _removePhoto(context, controller);
    return;
  }

  final picked = await ImagePicker().pickImage(
    source: action == _PhotoAction.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: _maxAvatarEdge,
    maxHeight: _maxAvatarEdge,
    imageQuality: 85,
  );
  if (picked == null || !context.mounted) return;

  final bytes = await picked.readAsBytes();
  if (!context.mounted) return;

  final l10n = context.l10n;
  if (bytes.length > _maxAvatarBytes) {
    _tell(context, l10n.profilePhotoTooLarge);
    return;
  }

  try {
    await controller.setAvatarFromBytes(bytes: bytes, fileName: picked.name);
    if (!context.mounted) return;
    _tell(context, l10n.profilePhotoUpdated);
  } on UnsupportedAvatarFormatException {
    if (!context.mounted) return;
    _tell(context, l10n.profilePhotoUnsupported);
  } on Object {
    if (!context.mounted) return;
    _tell(context, l10n.profilePhotoFailed);
  }
}

Future<void> _removePhoto(
  BuildContext context,
  ProfileController controller,
) async {
  final l10n = context.l10n;
  try {
    await controller.removeAvatar();
    if (!context.mounted) return;
    _tell(context, l10n.profilePhotoRemoved);
  } on Object {
    if (!context.mounted) return;
    _tell(context, l10n.profilePhotoFailed);
  }
}

void _tell(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _PhotoActionSheet extends StatelessWidget {
  const _PhotoActionSheet({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The browser has no camera source worth offering: it opens the same file
    // dialog as the library, so two rows would be one row twice.
    final showCamera = !AppCapabilities.instance.isWeb;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileChangePhoto,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (showCamera)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.profileTakePhoto),
              onTap: () => Navigator.of(context).pop(_PhotoAction.camera),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.profileChoosePhoto),
            onTap: () => Navigator.of(context).pop(_PhotoAction.library),
          ),
          if (hasPhoto)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.profileRemovePhoto,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
            ),
        ],
      ),
    );
  }
}
