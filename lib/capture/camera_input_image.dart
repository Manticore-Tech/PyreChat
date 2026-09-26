import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

const _orientationDegrees = <DeviceOrientation, int>{
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

InputImageRotation? inputImageRotation(
  CameraController controller,
  CameraDescription camera,
) {
  if (Platform.isIOS) {
    return InputImageRotationValue.fromRawValue(
      _orientationDegrees[controller.value.deviceOrientation] ?? 0,
    );
  }

  final deviceRotation = _orientationDegrees[controller.value.deviceOrientation];
  if (deviceRotation == null) return null;

  final compensation = camera.lensDirection == CameraLensDirection.front
      ? (camera.sensorOrientation + deviceRotation) % 360
      : (camera.sensorOrientation - deviceRotation + 360) % 360;

  return InputImageRotationValue.fromRawValue(compensation);
}

InputImage? inputImageFromCameraImage(
  CameraImage image,
  CameraController controller,
  CameraDescription camera,
) {
  final rotation = inputImageRotation(controller, camera);
  if (rotation == null) return null;

  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  if (Platform.isAndroid) {
    if (format == InputImageFormat.nv21 && image.planes.length == 1) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    if (format == InputImageFormat.yuv_420_888) {
      return InputImage.fromBytes(
        bytes: image.toNv21(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }
    return null;
  }

  if (format == InputImageFormat.bgra8888 && image.planes.length == 1) {
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  return null;
}

extension _Nv21 on CameraImage {
  Uint8List toNv21() {
    final yPlane = planes[0];
    final uPlane = planes[1];
    final vPlane = planes[2];

    final ySize = width * height;
    final nv21 = Uint8List(ySize + ySize ~/ 2);

    var offset = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes.sublist(rowStart, rowStart + width));
      offset += width;
    }

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    var uvOffset = ySize;
    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < width ~/ 2; col++) {
        final uvIndex = row * uvRowStride + col * uvPixelStride;
        nv21[uvOffset++] = vPlane.bytes[uvIndex];
        nv21[uvOffset++] = uPlane.bytes[uvIndex];
      }
    }
    return nv21;
  }
}
