import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/pyre_camera_kit.dart';

void main() {
  test('Camera Kit routes image MIME types to image preview', () {
    for (final kind in ['image', 'image/jpeg', 'image/png', ' IMAGE/HEIC ']) {
      final result = CameraKitCaptureResult(path: '/capture', kind: kind);
      expect(result.isImage, isTrue, reason: kind);
      expect(result.isVideo, isFalse, reason: kind);
    }
  });

  test('Camera Kit routes video MIME types to video review', () {
    for (final kind in ['video', 'video/mp4', 'video/quicktime', ' VIDEO/MP4 ']) {
      final result = CameraKitCaptureResult(path: '/capture', kind: kind);
      expect(result.isVideo, isTrue, reason: kind);
      expect(result.isImage, isFalse, reason: kind);
    }
  });

  test('Camera Kit rejects unknown or misleading capture kinds', () {
    for (final kind in ['', 'application/octet-stream', 'videoevil', 'imagex']) {
      final result = CameraKitCaptureResult(path: '/capture', kind: kind);
      expect(result.isImage, isFalse, reason: kind);
      expect(result.isVideo, isFalse, reason: kind);
    }
  });
  test('Camera Kit keeps the native MIME on upload', () {
    for (final entry in <(String, String)>[
      ('image', 'image/jpeg'),
      ('video', 'video/mp4'),
      (' image/png ', 'image/png'),
      (' IMAGE/HEIC ', 'image/heic'),
      ('video/quicktime', 'video/quicktime'),
      ('VIDEO/MP4; codecs=h264', 'video/mp4'),
    ]) {
      final result = CameraKitCaptureResult(path: '/capture', kind: entry.$1);
      expect(result.uploadMime, entry.$2, reason: entry.$1);
    }
  });

  test('Camera Kit rejects incomplete and non-media MIME', () {
    for (final kind in ['image/', 'video/', 'text/plain', 'video/..', '']) {
      final result = CameraKitCaptureResult(path: '/capture', kind: kind);
      expect(result.uploadMime, isNull, reason: kind);
      expect(result.isImage, isFalse, reason: kind);
      expect(result.isVideo, isFalse, reason: kind);
    }
  });

}
