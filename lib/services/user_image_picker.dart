import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

enum UserImagePurpose { profile, background }

abstract final class UserImagePicker {
  static final ImagePicker _picker = ImagePicker();

  static Future<Uint8List?> pick(UserImagePurpose purpose) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: purpose == UserImagePurpose.profile ? 1200 : 2600,
      maxHeight: purpose == UserImagePurpose.profile ? 1200 : 2600,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (picked == null) return null;

    final sourceBytes = await picked.readAsBytes();
    final decoded = image.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('That image could not be decoded.');
    }

    final maxEdge = purpose == UserImagePurpose.profile ? 900 : 2200;
    image.Image normalized = decoded;
    if (decoded.width > maxEdge || decoded.height > maxEdge) {
      if (decoded.width >= decoded.height) {
        normalized = image.copyResize(
          decoded,
          width: maxEdge,
          interpolation: image.Interpolation.cubic,
        );
      } else {
        normalized = image.copyResize(
          decoded,
          height: maxEdge,
          interpolation: image.Interpolation.cubic,
        );
      }
    }

    final quality = purpose == UserImagePurpose.profile ? 88 : 84;
    return Uint8List.fromList(
      image.encodeJpg(normalized, quality: quality),
    );
  }
}
