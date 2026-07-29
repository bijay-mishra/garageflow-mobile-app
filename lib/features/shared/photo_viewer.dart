import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/photo.dart';

/// Full-screen photo viewer: swipe between shots, pinch to zoom.
///
/// Black background and no chrome but the caption — the photo is the content,
/// and a mechanic checking a scratch wants it edge to edge.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  final List<JobPhoto> photos;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_index + 1} of ${widget.photos.length}',
          style: const TextStyle(fontSize: 15, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) => setState(() => _index = index),
              itemCount: widget.photos.length,
              itemBuilder: (context, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    widget.photos[index].url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                            size: 46,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Could not load this photo',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white54,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          photo.kind,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${photo.uploadedBy} · ${Fmt.timeAgo(photo.uploadedAt)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (photo.caption.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      photo.caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
