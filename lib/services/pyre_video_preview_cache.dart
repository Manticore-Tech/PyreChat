import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PyreVideoPreviewCache {
  PyreVideoPreviewCache._();

  static const MethodChannel _channel = MethodChannel(
    'dev.pyrearms.pyrechat_flutter/video_preview',
  );

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<String?> cache(Uint8List bytes) async {
    if (!isSupported || bytes.isEmpty) return null;
    try {
      return await _channel.invokeMethod<String>('cacheVideo', {
        'bytes': bytes,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> delete(String? path) async {
    if (!isSupported || path == null || path.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('deleteCachedVideo', {'path': path});
    } on PlatformException {
      // Cache cleanup is best-effort.
    } on MissingPluginException {
      // Cache cleanup is best-effort.
    }
  }
}
