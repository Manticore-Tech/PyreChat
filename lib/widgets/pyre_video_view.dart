import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PyreVideoView extends StatelessWidget {
  const PyreVideoView({
    super.key,
    required this.path,
    this.fallback,
  });

  final String path;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final cleanPath = path.trim();
    final supported =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        cleanPath.isNotEmpty;

    if (!supported) {
      return fallback ?? const ColoredBox(color: Colors.black);
    }

    return AndroidView(
      viewType: 'pyrechat/video_preview',
      creationParams: <String, Object?>{'path': cleanPath},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
