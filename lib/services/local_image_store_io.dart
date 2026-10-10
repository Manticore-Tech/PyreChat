import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> writeImage({
  required String name,
  required Uint8List bytes,
}) async {
  final root = await getApplicationSupportDirectory();
  final directory = Directory('${root.path}${Platform.pathSeparator}pyrechat_user_media');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Uint8List?> readImage(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> deleteImage(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
