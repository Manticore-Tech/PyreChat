import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:image/image.dart' as img;
import 'package:pyrechat_flutter/capture/camera_input_image.dart';
import 'package:pyrechat_flutter/capture/custom_lens.dart';
import 'package:pyrechat_flutter/capture/custom_lens_renderer.dart';
import 'package:pyrechat_flutter/capture/lens_renderer.dart';
import 'package:pyrechat_flutter/capture/pyre_landmarks.dart';
import 'package:pyrechat_flutter/capture/pyre_lenses.dart';
import 'package:pyrechat_flutter/capture/tracking_smoother.dart';

/// Native-speed tracking: analysis stream only, no frame conversion.
class FaceLensTracker {
  FaceLensTracker() : _smoother = MeshSmoother(468);

  final _detector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
  final MeshSmoother _smoother;
  MeshFrame? _mesh;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  int _frameCount = 0;
  bool _busy = false;

  MeshFrame? get meshFrame => _mesh;
  InputImageRotation get rotation => _rotation;

  /// Fire-and-forget — never block the camera image stream callback.
  void enqueueFrame({
    required CameraImage image,
    required CameraController controller,
    required CameraDescription camera,
    required void Function(MeshFrame? frame) onResult,
  }) {
    // ML Kit face mesh detection is available on Android only.
    if (!Platform.isAndroid) return;
    _frameCount++;
    if (_busy || _frameCount % 3 != 0) return;

    final input = inputImageFromCameraImage(image, controller, camera);
    if (input == null) return;

    _busy = true;
    final timeUs = DateTime.now().microsecondsSinceEpoch;
    unawaited((() async {
      try {
        final meshes = await _detector.processImage(input);
        _rotation = input.metadata!.rotation;
        if (meshes.isEmpty) {
          _mesh = null;
          onResult(null);
          return;
        }
        final size = input.metadata!.size;
        final pixels = meshes.first.points.map((p) => Offset(p.x, p.y)).toList();
        final smoothed = _smoother.smooth(pixels, timeUs);
        _mesh = MeshFrame(
          pixels: smoothed,
          imageSize: size,
          rotation: _rotation,
          lens: camera.lensDirection,
        );
        onResult(_mesh);
      } catch (_) {
        onResult(_mesh);
      } finally {
        _busy = false;
      }
    })());
  }

  void reset() {
    _mesh = null;
    _smoother.reset();
  }

  Future<void> dispose() => _detector.close();

  Future<List<Offset>?> detectOnFile(String path) async {
    if (!Platform.isAndroid) return null;
    final meshes = await _detector.processImage(InputImage.fromFilePath(path));
    if (meshes.isEmpty) return null;
    return meshes.first.points.map((p) => Offset(p.x, p.y)).toList();
  }
}

Future<img.Image> compositeLensOnImage({
  required img.Image source,
  required List<Offset> imageSpacePoints,
  required PyreLensId lens,
  required CameraLensDirection lensDirection,
}) async {
  if (lens == PyreLensId.none || imageSpacePoints.length < 468) return source;

  final imageSize = Size(source.width.toDouble(), source.height.toDouble());
  final norm = meshToNormalized(
    imageSpacePoints,
    imageSize,
    canvasSize: imageSize,
    rotation: InputImageRotation.rotation0deg,
    lens: lensDirection,
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rgba = Uint8List(source.width * source.height * 4);
  var i = 0;
  for (final p in source) {
    rgba[i++] = p.r.toInt();
    rgba[i++] = p.g.toInt();
    rgba[i++] = p.b.toInt();
    rgba[i++] = p.a.toInt();
  }
  final uiImage = await _decodeRgba(rgba, source.width, source.height);
  canvas.drawImage(uiImage, Offset.zero, Paint());
  LensRenderer.drawNormalized(
    canvas,
    norm,
    Size(source.width.toDouble(), source.height.toDouble()),
    lens,
    DateTime.now().millisecondsSinceEpoch.toDouble(),
  );

  final picture = recorder.endRecording();
  final out = await picture.toImage(source.width, source.height);
  final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return source;
  return img.decodeImage(bytes.buffer.asUint8List()) ?? source;
}

Future<img.Image> compositeCustomLensOnImage({
  required img.Image source,
  required List<Offset> imageSpacePoints,
  required CustomLensDef lens,
  required Map<String, ui.Image> stickerImages,
  required CameraLensDirection lensDirection,
}) async {
  if (imageSpacePoints.length < 468 || lens.elements.isEmpty) return source;

  final imageSize = Size(source.width.toDouble(), source.height.toDouble());
  final norm = meshToNormalized(
    imageSpacePoints,
    imageSize,
    canvasSize: imageSize,
    rotation: InputImageRotation.rotation0deg,
    lens: lensDirection,
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rgba = Uint8List(source.width * source.height * 4);
  var j = 0;
  for (final p in source) {
    rgba[j++] = p.r.toInt();
    rgba[j++] = p.g.toInt();
    rgba[j++] = p.b.toInt();
    rgba[j++] = p.a.toInt();
  }
  final uiImage = await _decodeRgba(rgba, source.width, source.height);
  canvas.drawImage(uiImage, Offset.zero, Paint());
  CustomLensRenderer.draw(
    canvas,
    norm,
    Size(source.width.toDouble(), source.height.toDouble()),
    lens,
    stickerImages,
  );

  final picture = recorder.endRecording();
  final out = await picture.toImage(source.width, source.height);
  final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return source;
  return img.decodeImage(bytes.buffer.asUint8List()) ?? source;
}

Future<ui.Image> _decodeRgba(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

