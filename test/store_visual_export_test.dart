import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void _fillRect(img.Image image, int x1, int y1, int x2, int y2, int r, int g, int b) {
  final left = math.max(0, math.min(x1, x2));
  final right = math.min(image.width - 1, math.max(x1, x2));
  final top = math.max(0, math.min(y1, y2));
  final bottom = math.min(image.height - 1, math.max(y1, y2));
  for (var y = top; y <= bottom; y++) {
    for (var x = left; x <= right; x++) {
      image.setPixelRgb(x, y, r, g, b);
    }
  }
}

void _strokeRect(
  img.Image image,
  int x1,
  int y1,
  int x2,
  int y2,
  int thickness,
  int r,
  int g,
  int b,
) {
  _fillRect(image, x1, y1, x2, y1 + thickness - 1, r, g, b);
  _fillRect(image, x1, y2 - thickness + 1, x2, y2, r, g, b);
  _fillRect(image, x1, y1, x1 + thickness - 1, y2, r, g, b);
  _fillRect(image, x2 - thickness + 1, y1, x2, y2, r, g, b);
}

void _drawLine(
  img.Image image,
  int x0,
  int y0,
  int x1,
  int y1,
  int thickness,
  int r,
  int g,
  int b,
) {
  var x = x0;
  var y = y0;
  final dx = (x1 - x0).abs();
  final sx = x0 < x1 ? 1 : -1;
  final dy = -(y1 - y0).abs();
  final sy = y0 < y1 ? 1 : -1;
  var err = dx + dy;

  while (true) {
    final half = thickness ~/ 2;
    _fillRect(image, x - half, y - half, x + half, y + half, r, g, b);
    if (x == x1 && y == y1) break;
    final e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y += sy;
    }
  }
}

void _drawChatBubble(
  img.Image image,
  int x,
  int y,
  int w,
  int h, {
  required int borderR,
  required int borderG,
  required int borderB,
  required int fillR,
  required int fillG,
  required int fillB,
  required bool tailRight,
}) {
  _fillRect(image, x, y, x + w, y + h, fillR, fillG, fillB);
  _strokeRect(image, x, y, x + w, y + h, 5, borderR, borderG, borderB);

  final tailX = tailRight ? x + w - 24 : x + 24;
  final dir = tailRight ? 1 : -1;
  for (var i = 0; i < 24; i++) {
    final width = math.max(1, (24 - i) ~/ 2);
    _fillRect(
      image,
      tailX + dir * i - width,
      y + h + i,
      tailX + dir * i + width,
      y + h + i,
      borderR,
      borderG,
      borderB,
    );
  }
}

void main() {
  test('export Google Play visual package', () {
    final iconSourceFile = File('assets/app_icon.png');
    final flameSourceFile = File('assets/pyre_flame.png');

    expect(iconSourceFile.existsSync(), isTrue);
    expect(flameSourceFile.existsSync(), isTrue);

    final iconSource = img.decodeImage(iconSourceFile.readAsBytesSync());
    final flameSource = img.decodeImage(flameSourceFile.readAsBytesSync());

    expect(iconSource, isNotNull);
    expect(flameSource, isNotNull);

    final outDir = Directory('store/google-play/en-US')..createSync(recursive: true);

    final iconCanvas = img.Image(width: 512, height: 512, numChannels: 4);
    for (var y = 0; y < iconCanvas.height; y++) {
      for (var x = 0; x < iconCanvas.width; x++) {
        iconCanvas.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
    final resizedIcon = img.copyResize(
      iconSource!,
      width: 512,
      height: 512,
      interpolation: img.Interpolation.cubic,
    );
    img.compositeImage(iconCanvas, resizedIcon, dstX: 0, dstY: 0);

    final iconFile = File('${outDir.path}/icon-512.png');
    iconFile.writeAsBytesSync(img.encodePng(iconCanvas, level: 6), flush: true);

    final feature = img.Image(width: 1024, height: 500, numChannels: 3);
    for (var y = 0; y < feature.height; y++) {
      for (var x = 0; x < feature.width; x++) {
        final nx = (x - 512) / 512.0;
        final ny = (y - 250) / 250.0;
        final radial = math.max(0.0, 1.0 - math.sqrt(nx * nx + ny * ny));
        final horizon = math.max(0.0, 1.0 - (y - 250).abs() / 250.0);

        final r = (8 + 26 * radial + 10 * horizon).round().clamp(0, 255);
        final g = (9 + 9 * radial + 4 * horizon).round().clamp(0, 255);
        final b = (11 + 5 * radial + 2 * horizon).round().clamp(0, 255);
        feature.setPixelRgb(x, y, r, g, b);
      }
    }

    for (var radius = 170; radius >= 10; radius -= 8) {
      final strength = (1.0 - radius / 180.0);
      final glowR = (34 + 170 * strength).round().clamp(0, 255);
      final glowG = (18 + 62 * strength).round().clamp(0, 255);
      final glowB = (10 + 8 * strength).round().clamp(0, 255);
      final rr = radius * radius;
      for (var y = math.max(0, 250 - radius); y <= math.min(499, 250 + radius); y++) {
        final dy = y - 250;
        final dx = math.sqrt(math.max(0, rr - dy * dy)).round();
        final left = math.max(0, 512 - dx);
        final right = math.min(1023, 512 + dx);
        for (var x = left; x <= right; x++) {
          final current = feature.getPixel(x, y);
          final mix = 0.035 + 0.055 * strength;
          final nr = (current.r * (1 - mix) + glowR * mix).round().clamp(0, 255);
          final ng = (current.g * (1 - mix) + glowG * mix).round().clamp(0, 255);
          final nb = (current.b * (1 - mix) + glowB * mix).round().clamp(0, 255);
          feature.setPixelRgb(x, y, nr, ng, nb);
        }
      }
    }

    _drawChatBubble(
      feature,
      120,
      164,
      230,
      132,
      borderR: 118,
      borderG: 74,
      borderB: 42,
      fillR: 15,
      fillG: 17,
      fillB: 20,
      tailRight: true,
    );
    _drawChatBubble(
      feature,
      674,
      164,
      230,
      132,
      borderR: 118,
      borderG: 74,
      borderB: 42,
      fillR: 15,
      fillG: 17,
      fillB: 20,
      tailRight: false,
    );

    _drawLine(feature, 350, 230, 422, 230, 5, 201, 105, 34);
    _drawLine(feature, 602, 230, 674, 230, 5, 238, 170, 67);
    _drawLine(feature, 350, 252, 422, 252, 3, 94, 56, 34);
    _drawLine(feature, 602, 252, 674, 252, 3, 94, 56, 34);

    final resizedFlame = img.copyResize(
      flameSource!,
      width: 190,
      height: 190,
      interpolation: img.Interpolation.cubic,
    );
    img.compositeImage(feature, resizedFlame, dstX: 417, dstY: 155);

    final featureFile = File('${outDir.path}/feature-graphic-1024x500.png');
    featureFile.writeAsBytesSync(img.encodePng(feature, level: 6), flush: true);

    final iconCheck = img.decodePng(iconFile.readAsBytesSync());
    final featureCheck = img.decodePng(featureFile.readAsBytesSync());

    expect(iconCheck, isNotNull);
    expect(featureCheck, isNotNull);
    expect(iconCheck!.width, 512);
    expect(iconCheck.height, 512);
    expect(iconCheck.numChannels, 4);
    expect(iconFile.lengthSync(), lessThanOrEqualTo(1024 * 1024));

    expect(featureCheck!.width, 1024);
    expect(featureCheck.height, 500);
    expect(featureCheck.numChannels, 3);

    final validation = <String, Object?>{
      'generated_at': '2026-10-07T06:25:58-04:00',
      'icon': {
        'path': 'store/google-play/en-US/icon-512.png',
        'source': 'assets/app_icon.png',
        'width': iconCheck.width,
        'height': iconCheck.height,
        'channels': iconCheck.numChannels,
        'bytes': iconFile.lengthSync(),
        'max_bytes': 1024 * 1024,
        'validation': 'PASS',
      },
      'feature_graphic': {
        'path': 'store/google-play/en-US/feature-graphic-1024x500.png',
        'sources': [
          'assets/pyre_flame.png',
          'Brand & Visual Designer procedural ember/chat composition'
        ],
        'width': featureCheck.width,
        'height': featureCheck.height,
        'channels': featureCheck.numChannels,
        'bytes': featureFile.lengthSync(),
        'alpha': false,
        'validation': 'PASS',
      },
      'publication': false,
    };

    File('${outDir.path}/VALIDATION.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(validation),
      flush: true,
    );
  });
}
