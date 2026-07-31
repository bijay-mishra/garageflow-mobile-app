import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../models/auth_user.dart';
import '../state/auth_controller.dart';
import 'states.dart';

/// Someone's photo, or their initials.
///
/// Initials are the fallback rather than a grey silhouette: a circle with "RS"
/// in it identifies the person, and a generic avatar icon says only "no photo",
/// which the empty space already said.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.user,
    this.size = 44,
    this.onDark = true,
  });

  final AuthUser user;
  final double size;

  /// True when drawn on a gradient header, which needs a light translucent
  /// treatment rather than the brand blue.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final border = onDark
        ? Colors.white.withValues(alpha: 0.28)
        : AppTheme.of(context).border;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.18)
            : AppTheme.brand.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.4),
      ),
      child: user.hasPhoto
          ? Image.network(
              user.photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // A photo that will not load falls back to the initials rather
              // than to a broken-image glyph. The commonest cause is the phone
              // being off the tunnel, which is temporary and not worth shouting
              // about.
              errorBuilder: (_, _, _) => _Initials(user: user, size: size, onDark: onDark),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _Initials(user: user, size: size, onDark: onDark),
            )
          : _Initials(user: user, size: size, onDark: onDark),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.user, required this.size, required this.onDark});

  final AuthUser user;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Text(
    user.initials,
    style: TextStyle(
      color: onDark ? Colors.white : AppTheme.brand,
      fontSize: size * 0.36,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    ),
  );
}

/// The avatar in the profile header, tappable to change the photo.
class ProfilePhotoButton extends StatefulWidget {
  const ProfilePhotoButton({super.key, this.size = 52});

  final double size;

  @override
  State<ProfilePhotoButton> createState() => _ProfilePhotoButtonState();
}

class _ProfilePhotoButtonState extends State<ProfilePhotoButton> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    final auth = context.read<AuthController>();

    // Downsized before it leaves the phone. The API refuses anything over 4 MB
    // and a modern camera clears that in one shot, so resizing here is what
    // makes the upload work at all rather than an optimisation.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: AppConfig.photoMaxWidth.toDouble(),
      imageQuality: AppConfig.photoQuality,
    );

    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    final failure = await auth.setPhoto(picked.path);
    if (!mounted) return;
    setState(() => _busy = false);

    showSnack(
      context,
      failure ?? AppText.of(context)('profile.photoUpdated'),
      isError: failure != null,
    );
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    final failure = await context.read<AuthController>().removePhoto();
    if (!mounted) return;
    setState(() => _busy = false);

    showSnack(
      context,
      failure ?? AppText.of(context)('profile.photoRemoved'),
      isError: failure != null,
    );
  }

  Future<void> _sheet() async {
    final t = AppText.of(context);
    final hasPhoto = context.read<AuthController>().user?.hasPhoto ?? false;

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t('profile.takePhoto')),
              onTap: () => Navigator.pop(sheet, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t('profile.choosePhoto')),
              onTap: () => Navigator.pop(sheet, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.rose,
                ),
                title: Text(
                  t('profile.removePhoto'),
                  style: const TextStyle(color: AppTheme.rose),
                ),
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;

    switch (choice) {
      case 'camera':
        await _pick(ImageSource.camera);
      case 'gallery':
        await _pick(ImageSource.gallery);
      case 'remove':
        await _remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    if (user == null) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: AppText.of(context)('profile.editPhoto'),
      child: GestureDetector(
        onTap: _busy ? null : _sheet,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileAvatar(user: user, size: widget.size),
            if (_busy)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.ink900.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ),
              )
            else
              // A small camera badge, because a tappable avatar is otherwise
              // indistinguishable from a decorative one.
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.shadowCard,
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 11,
                    color: AppTheme.brand,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
