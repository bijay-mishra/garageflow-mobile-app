import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/photo.dart';
import '../../services/mechanic_service.dart';
import '../../widgets/states.dart';

/// Take or choose a photo, label it, send it.
///
/// The image is downsized on the way out of the picker rather than on the way
/// into the request: the API rejects anything over 4 MB and a modern phone
/// camera clears that in a single shot, so an untouched original would fail
/// every time on a good camera.
class PhotoUploadSheet extends StatefulWidget {
  const PhotoUploadSheet({super.key, required this.jobId});

  final String jobId;

  @override
  State<PhotoUploadSheet> createState() => _PhotoUploadSheetState();
}

class _PhotoUploadSheetState extends State<PhotoUploadSheet> {
  final _picker = ImagePicker();
  final _caption = TextEditingController();

  XFile? _file;
  String _kind = 'during';
  bool _uploading = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: AppConfig.photoMaxWidth.toDouble(),
        imageQuality: AppConfig.photoQuality,
      );

      if (picked != null && mounted) setState(() => _file = picked);
    } on Exception catch (error) {
      // Usually a denied camera permission. The platform message is the useful
      // one here — it names the permission.
      if (mounted) showSnack(context, '$error', isError: true);
    }
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null) return;

    setState(() => _uploading = true);

    try {
      await context.read<MechanicService>().uploadPhoto(
        widget.jobId,
        filePath: file.path,
        kind: _kind,
        caption: _caption.text,
      );

      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.ink200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Text('Add a photo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            const Text(
              'The customer can see these on their job.',
              style: TextStyle(fontSize: 13, color: AppTheme.ink500),
            ),
            const SizedBox(height: 18),

            if (_file == null)
              Row(
                children: [
                  Expanded(
                    child: _PickButton(
                      icon: Icons.photo_camera_rounded,
                      label: 'Camera',
                      onTap: () => _pick(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => _pick(ImageSource.gallery),
                    ),
                  ),
                ],
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Image.file(
                      File(_file!.path),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _file = null),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 18),
            const Text(
              'WHAT IS THIS SHOWING?',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink400,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in photoKinds)
                  ChoiceChip(
                    label: Text(kind),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                    selectedColor: AppTheme.brand.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _kind == kind ? AppTheme.brand : AppTheme.ink700,
                    ),
                    side: BorderSide(
                      color: _kind == kind ? AppTheme.brand : AppTheme.ink200,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _caption,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Caption',
                hintText: 'Worn front left pad',
                helperText: 'Optional',
                helperStyle: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.ink400,
                ),
              ),
            ),

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _file == null || _uploading ? null : _upload,
              child: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(_file == null ? 'Choose a photo first' : 'Upload'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.ink50,
    borderRadius: BorderRadius.circular(AppTheme.radius),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.ink200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: AppTheme.brand),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
