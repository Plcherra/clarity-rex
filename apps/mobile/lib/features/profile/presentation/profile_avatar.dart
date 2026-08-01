import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../theme/clarity_colors.dart';

/// The profile photo, falling back to the first letter of the name.
///
/// The link behind [imageUrl] is signed and expires, so failing to load is an
/// ordinary outcome here rather than an error worth showing. It drops back to
/// the initial, which is what someone with no photo sees anyway.
final class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.onTap,
    this.isBusy = false,
    this.size = 58,
  });

  final String name;
  final String? imageUrl;
  final VoidCallback onTap;
  final bool isBusy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final radius = BorderRadius.circular(size * 0.34);

    return Semantics(
      button: true,
      label: context.l10n.profileChangePhoto,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: radius,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: radius,
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: _content(context),
                  ),
                ),
              ),
              Positioned(right: -2, bottom: -2, child: _badge(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (isBusy) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final url = imageUrl;
    if (url == null || url.isEmpty) return _initial(context);

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (context, _, _) => _initial(context),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _initial(context),
    );
  }

  Widget _initial(BuildContext context) {
    final trimmed = name.trim();
    return Center(
      child: Text(
        trimmed.isEmpty ? 'C' : trimmed[0].toUpperCase(),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: context.clarityColors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  /// Without this the photo looks like decoration rather than something you
  /// can tap to change.
  Widget _badge(BuildContext context) {
    final colors = context.clarityColors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Icon(
        Icons.photo_camera_outlined,
        size: size * 0.24,
        color: colors.textMuted,
      ),
    );
  }
}
