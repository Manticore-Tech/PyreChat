import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/snap_detail.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_video_preview_cache.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_video_view.dart';

class SnapViewerScreen extends StatefulWidget {
  const SnapViewerScreen({
    super.key,
    required this.snapId,
    required this.markViewed,
    this.client,
  });

  final String snapId;
  final bool markViewed;
  final PyreClient? client;

  @override
  State<SnapViewerScreen> createState() => _SnapViewerScreenState();
}

class _SnapViewerScreenState extends State<SnapViewerScreen> {
  late final PyreClient _client;

  SnapDetail? _snap;
  Uint8List? _bytes;
  String? _videoPath;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PyreClient();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _client.getSnap(widget.snapId);
      if (widget.markViewed) {
        await _client.markSnapViewed(widget.snapId);
      }
      final bytes = await _client.fetchSnapMedia(snap);
      final videoPath = snap.kind == 'video'
          ? await PyreVideoPreviewCache.cache(bytes)
          : null;
      if (!mounted) {
        await PyreVideoPreviewCache.delete(videoPath);
        return;
      }
      setState(() {
        _snap = snap;
        _bytes = bytes;
        _videoPath = videoPath;
        _loading = false;
      });
    } on PyreApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Pyre';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    final videoPath = _videoPath;
    _videoPath = null;
    PyreVideoPreviewCache.delete(videoPath);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_bytes != null && _snap?.kind != 'video')
            InteractiveViewer(
              child: Center(
                child: Image.memory(_bytes!, fit: BoxFit.contain),
              ),
            ),
          if (_bytes != null && _snap?.kind == 'video')
            _videoPath != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      PyreVideoView(
                        path: _videoPath!,
                        fallback: const ColoredBox(color: Colors.black),
                      ),
                      const IgnorePointer(
                        child: Align(
                          alignment: Alignment(0, 0.82),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x78000000),
                              borderRadius: BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Text(
                                'Tap video to pause or play',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Text(
                        'Video preview unavailable on this device.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: PyreColors.ember)),
          if (_error != null)
            Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                if (_snap != null)
                  Expanded(
                    child: Text(
                      _snap!.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_snap != null && _snap!.caption.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Text(
                _snap!.caption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool?> openSnapViewer(
  BuildContext context, {
  required String snapId,
  required bool markViewed,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SnapViewerScreen(snapId: snapId, markViewed: markViewed),
    ),
  );
}
