import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image/image.dart' as img;

/// Converts a [CameraImage] stream frame into a [ui.Image] for painting.
Future<ui.Image?> cameraImageToUi(
  CameraImage image, {
  InputImageRotation rotation = InputImageRotation.rotation0deg,
}) async {
  var decoded = _toImg(image);
  if (decoded == null) return null;

  decoded = _rotateForDisplay(decoded, rotation);

  final rgba = Uint8List(decoded.width * decoded.height * 4);
  var i = 0;
  for (final p in decoded) {
    rgba[i++] = p.r.toInt();
    rgba[i++] = p.g.toInt();
    rgba[i++] = p.b.toInt();
    rgba[i++] = 255;
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    decoded.width,
    decoded.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

img.Image? _toImg(CameraImage image) {
  if (image.format.group == ImageFormatGroup.bgra8888) {
    return _bgra8888(image);
  }
  if (image.format.group == ImageFormatGroup.yuv420 ||
      image.format.group == ImageFormatGroup.nv21) {
    return _yuv420(image);
  }
  return null;
}

img.Image _bgra8888(CameraImage image) {
  final plane = image.planes.first;
  final out = img.Image(width: image.width, height: image.height);
  final bytes = plane.bytes;
  final rowStride = plane.bytesPerRow;
  for (var y = 0; y < image.height; y++) {
    var i = y * rowStride;
    for (var x = 0; x < image.width; x++) {
      final b = bytes[i++];
      final g = bytes[i++];
      final r = bytes[i++];
      i++; // alpha
      out.setPixelRgb(x, y, r, g, b);
    }
  }
  return out;
}

img.Image _yuv420(CameraImage image) {
  final out = img.Image(width: image.width, height: image.height);
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final yIndex = y * yPlane.bytesPerRow + x;
      final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
      final yVal = yPlane.bytes[yIndex];
      final uVal = uPlane.bytes[uvIndex];
      final vVal = vPlane.bytes[uvIndex];

      final c = yVal - 16;
      final d = uVal - 128;
      final e = vVal - 128;
      final r = (298 * c + 409 * e + 128) >> 8;
      final g = (298 * c - 100 * d - 208 * e + 128) >> 8;
      final b = (298 * c + 516 * d + 128) >> 8;
      out.setPixelRgb(
        x,
        y,
        r.clamp(0, 255),
        g.clamp(0, 255),
        b.clamp(0, 255),
      );
    }
  }
  return out;
}

img.Image _rotateForDisplay(img.Image src, InputImageRotation rotation) {
  return switch (rotation) {
    InputImageRotation.rotation0deg => src,
    InputImageRotation.rotation90deg => img.copyRotate(src, angle: 90),
    InputImageRotation.rotation180deg => img.copyRotate(src, angle: 180),
    InputImageRotation.rotation270deg => img.copyRotate(src, angle: 270),
  };
}
