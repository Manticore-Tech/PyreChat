import 'dart:typed_data';

final _memoryImages = <String, Uint8List>{};

Future<String?> writeImage({
  required String name,
  required Uint8List bytes,
}) async {
  final key = 'memory://$name';
  _memoryImages[key] = Uint8List.fromList(bytes);
  return key;
}

Future<Uint8List?> readImage(String path) async {
  final bytes = _memoryImages[path];
  return bytes == null ? null : Uint8List.fromList(bytes);
}

Future<void> deleteImage(String path) async {
  _memoryImages.remove(path);
}
