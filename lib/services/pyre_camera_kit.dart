import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CameraKitCaptureResult {
  const CameraKitCaptureResult({
    required this.path,
    required this.kind,
  });

  final String path;
  final String kind;

  String get _normalizedKind =>
      kind.trim().toLowerCase().split(';').first.trim();

  /// Preserve the actual capture type instead of mislabeling PNG/HEIC/MOV
  /// bytes as JPEG or MP4 on upload.
  String? get uploadMime {
    if (_normalizedKind == 'image') return 'image/jpeg';
    if (_normalizedKind == 'video') return 'video/mp4';
    if (RegExp(r'^(image|video)/[a-z0-9][a-z0-9.+-]*$')
        .hasMatch(_normalizedKind)) {
      return _normalizedKind;
    }
    return null;
  }

  bool get isImage => uploadMime?.startsWith('image/') == true;
  bool get isVideo => uploadMime?.startsWith('video/') == true;
}

class PyreCameraKit {
  PyreCameraKit._();

  static final PyreCameraKit instance = PyreCameraKit._();

  static const MethodChannel _channel =
      MethodChannel('dev.pyrearms.pyrechat/camera_kit');

  bool get _isSupportedMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> get isConfigured async {
    if (!_isSupportedMobile) return false;
    try {
      return await _channel.invokeMethod<bool>('isConfigured') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<CameraKitCaptureResult?> capture() async {
    if (!_isSupportedMobile) return null;

    final result = await _channel.invokeMapMethod<String, Object?>('openCapture');
    if (result == null) return null;

    final path = result['path']?.toString().trim();
    final kind = result['mime_type']?.toString().trim();

    if (path == null || path.isEmpty || kind == null || kind.isEmpty) {
      throw PlatformException(
        code: 'camera_kit_invalid_result',
        message: 'Camera Kit returned an invalid capture result',
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      throw PlatformException(
        code: 'camera_kit_missing_file',
        message: 'Camera Kit capture file was not found',
      );
    }

    return CameraKitCaptureResult(path: path, kind: kind);
  }
}
